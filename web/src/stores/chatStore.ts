import { create } from 'zustand'
import { clearAISession, streamChatSSE } from '../api/sse'
import type { SSEEvent } from '../api/types'
import { EXPERT_NAME_MAP, toolLabel } from '../utils/constants'

/** Agent 执行轨迹中的单条记录（tool_start/tool_end 配对为同一条） */
export interface TraceItem {
  id: number
  kind: 'tool' | 'expert' | 'rag'
  /** 原始工具名（专家调用为 consult_xxx_expert） */
  tool: string
  /** 中文展示名 */
  label: string
  args?: Record<string, unknown>
  result?: string
  status: 'running' | 'done'
  time: string
}

export interface ApprovalInfo {
  tool: string
  args: Record<string, unknown>
  summary: string
  status: 'pending' | 'approved' | 'rejected'
}

export interface ChatMessage {
  id: number
  role: 'user' | 'assistant'
  content: string
  traces: TraceItem[]
  approval?: ApprovalInfo
  status: 'streaming' | 'done' | 'error'
  error?: string
}

interface ChatState {
  sessionId: string
  messages: ChatMessage[]
  sending: boolean
  sendMessage: (text: string) => Promise<void>
  resolveApproval: (messageId: number, approved: boolean) => Promise<void>
  stopStreaming: () => void
  newSession: () => void
}

let idSeq = 1
const nextId = () => idSeq++
const now = () => new Date().toLocaleTimeString('zh-CN', { hour12: false })

function randomSessionId() {
  return `web_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
}

/** 把 SSE 事件合并进消息的轨迹列表（tool_start/tool_end 配对更新） */
function applyTraceEvent(traces: TraceItem[], evt: SSEEvent): TraceItem[] {
  if (evt.event === 'expert_handoff') {
    return [
      ...traces,
      {
        id: nextId(),
        kind: 'expert',
        tool: `consult_${evt.expert}_expert`,
        label: `分派给${evt.expert_name || EXPERT_NAME_MAP[evt.expert || ''] || evt.expert}`,
        args: { query: evt.query || '' },
        status: 'running',
        time: now(),
      },
    ]
  }

  if (evt.event === 'tool_start') {
    const isRag = evt.tool === 'search_knowledge_base'
    return [
      ...traces,
      {
        id: nextId(),
        kind: isRag ? 'rag' : 'tool',
        tool: evt.tool || '',
        label: toolLabel(evt.tool || ''),
        args: evt.args,
        status: 'running',
        time: now(),
      },
    ]
  }

  if (evt.event === 'tool_end') {
    // 回填最近的同名 running 轨迹；找不到则补一条完成态
    const copy = [...traces]
    for (let i = copy.length - 1; i >= 0; i--) {
      if (copy[i].tool === evt.tool && copy[i].status === 'running') {
        copy[i] = { ...copy[i], status: 'done', result: evt.result }
        return copy
      }
    }
    const isRag = evt.tool === 'search_knowledge_base'
    return [
      ...copy,
      {
        id: nextId(),
        kind: isRag ? 'rag' : 'tool',
        tool: evt.tool || '',
        label: toolLabel(evt.tool || ''),
        result: evt.result,
        status: 'done',
        time: now(),
      },
    ]
  }

  if (evt.event === 'rag_retrieve') {
    // tool_end 已带结果，这里仅确保知识检索轨迹类型标记为 rag
    return traces.map((t) =>
      t.tool === 'search_knowledge_base' ? { ...t, kind: 'rag' as const } : t,
    )
  }

  return traces
}

export const useChatStore = create<ChatState>((set, get) => {
  let abortController: AbortController | null = null

  /** 就地更新指定消息 */
  const patchMessage = (id: number, patch: (msg: ChatMessage) => Partial<ChatMessage>) =>
    set((state) => ({
      messages: state.messages.map((m) => (m.id === id ? { ...m, ...patch(m) } : m)),
    }))

  /** 消费一条 SSE 流，把事件写入指定助手消息 */
  const consumeStream = async (
    path: string,
    body: unknown,
    messageId: number,
  ): Promise<void> => {
    const controller = new AbortController()
    abortController = controller

    await streamChatSSE(
      path,
      body,
      (evt: SSEEvent) => {
        switch (evt.event) {
          case 'token':
            patchMessage(messageId, (m) => ({ content: m.content + (evt.token ?? '') }))
            break
          case 'tool_start':
          case 'tool_end':
          case 'expert_handoff':
          case 'rag_retrieve':
            patchMessage(messageId, (m) => ({ traces: applyTraceEvent(m.traces, evt) }))
            break
          case 'approval_required':
            patchMessage(messageId, () => ({
              approval: {
                tool: evt.tool ?? '',
                args: evt.args ?? {},
                summary: evt.summary ?? '',
                status: 'pending',
              },
              status: 'done',
            }))
            break
          case 'done':
            patchMessage(messageId, () => ({ status: 'done' }))
            break
          case 'error':
            patchMessage(messageId, () => ({
              status: 'error',
              error: evt.message || evt.error || '未知错误',
            }))
            break
        }
      },
      controller.signal,
    )
  }

  /** 流结束后的统一收尾（正常结束 / 中断 / 异常共用） */
  const finalize = (messageId: number, error?: unknown, aborted = false) => {
    abortController = null
    set({ sending: false })
    patchMessage(messageId, (m) => {
      if (error && !aborted) {
        return {
          status: 'error',
          error: error instanceof Error ? error.message : String(error),
        }
      }
      if (m.status !== 'streaming') return {}
      return aborted
        ? { status: 'done', content: m.content || '（已停止生成）' }
        : { status: 'done' }
    })
  }

  return {
    sessionId: randomSessionId(),
    messages: [],
    sending: false,

    sendMessage: async (text: string) => {
      const trimmed = text.trim()
      if (!trimmed || get().sending) return

      const assistantId = nextId()
      set((state) => ({
        sending: true,
        messages: [
          ...state.messages,
          { id: nextId(), role: 'user', content: trimmed, traces: [], status: 'done' },
          { id: assistantId, role: 'assistant', content: '', traces: [], status: 'streaming' },
        ],
      }))

      try {
        await consumeStream(
          '/api/chat',
          { message: trimmed, session_id: get().sessionId },
          assistantId,
        )
        finalize(assistantId)
      } catch (e) {
        finalize(assistantId, e, abortController === null)
      }
    },

    resolveApproval: async (messageId: number, approved: boolean) => {
      const msg = get().messages.find((m) => m.id === messageId)
      if (!msg?.approval || msg.approval.status !== 'pending' || get().sending) return

      set({ sending: true })
      patchMessage(messageId, (m) => ({
        approval: m.approval
          ? { ...m.approval, status: approved ? 'approved' : 'rejected' }
          : undefined,
        status: 'streaming',
      }))

      try {
        await consumeStream(
          '/api/chat/resume',
          { session_id: get().sessionId, approved },
          messageId,
        )
        finalize(messageId)
      } catch (e) {
        finalize(messageId, e, abortController === null)
      }
    },

    stopStreaming: () => {
      abortController?.abort()
      abortController = null
    },

    newSession: () => {
      abortController?.abort()
      abortController = null
      const oldSessionId = get().sessionId
      set({ sessionId: randomSessionId(), messages: [], sending: false })
      // 清理 AI 服务端会话历史，失败不影响新会话
      clearAISession(oldSessionId).catch(() => {})
    },
  }
})
