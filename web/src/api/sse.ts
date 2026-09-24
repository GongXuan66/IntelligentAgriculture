import { env } from '../config/env'
import type { SSEEvent } from './types'

const AI_BASE = env.aiBaseUrl.replace(/\/$/, '')

/**
 * 通过 fetch 流式消费 POST SSE（EventSource 只支持 GET，无法用于 /api/chat）。
 * 后端帧格式：data: {json}\n\n，事件类型在 JSON 载荷的 event 字段内。
 * 支持 AbortController 中断（对话页"停止"按钮）。
 */
export async function streamChatSSE(
  path: string,
  body: unknown,
  onEvent: (event: SSEEvent) => void,
  signal?: AbortSignal,
): Promise<void> {
  const resp = await fetch(`${AI_BASE}${path}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    },
    body: JSON.stringify(body),
    signal,
  })

  if (!resp.ok || !resp.body) {
    let detail = `AI 服务请求失败 (${resp.status})`
    try {
      const errBody = await resp.json()
      detail = errBody?.detail || errBody?.message || detail
    } catch {
      /* 保留默认错误信息 */
    }
    throw new Error(detail)
  }

  const reader = resp.body.getReader()
  const decoder = new TextDecoder('utf-8')
  let buffer = ''

  const dispatchFrame = (frame: string) => {
    const dataLines = frame
      .split('\n')
      .filter((line) => line.startsWith('data:'))
      .map((line) => line.slice(5).trimStart())
    if (dataLines.length === 0) return
    const dataStr = dataLines.join('\n')
    if (!dataStr) return
    try {
      onEvent(normalizeEvent(JSON.parse(dataStr) as SSEEvent))
    } catch {
      // 非 JSON 帧降级为 token，不中断流
      onEvent({ event: 'token', token: dataStr })
    }
  }

  for (;;) {
    const { done, value } = await reader.read()
    if (done) break
    buffer += decoder.decode(value, { stream: true })

    let idx: number
    while ((idx = buffer.indexOf('\n\n')) >= 0) {
      dispatchFrame(buffer.slice(0, idx))
      buffer = buffer.slice(idx + 2)
    }
  }
  // 收尾：缓冲区可能残留无结尾空行的最后一帧
  if (buffer.trim()) {
    dispatchFrame(buffer)
  }
}

/** 兼容旧版裸载荷：{token}/{done:true}/{error} 补齐统一 event 字段 */
function normalizeEvent(payload: SSEEvent): SSEEvent {
  if (payload.event) return payload
  const raw = payload as Record<string, unknown>
  if (typeof raw.token === 'string') return { ...payload, event: 'token' }
  if (raw.done === true) return { ...payload, event: 'done' }
  if (raw.error) return { ...payload, event: 'error', message: String(raw.error) }
  return payload
}

/** 清除 IA-AI 侧会话历史（开启新会话时调用） */
export async function clearAISession(sessionId: string): Promise<void> {
  await fetch(`${AI_BASE}/api/chat/clear`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ session_id: sessionId }),
  })
}
