import { useEffect, useRef } from 'react'
import { Button, Empty, Space, Typography } from 'antd'
import {
  PlusOutlined,
  RobotOutlined,
  UserOutlined,
} from '@ant-design/icons'
import { useChatStore } from '../stores/chatStore'
import type { ChatMessage } from '../stores/chatStore'
import AgentTimeline from '../components/chat/AgentTimeline'
import ApprovalCard from '../components/chat/ApprovalCard'
import ChatInput from '../components/chat/ChatInput'

const SUGGESTIONS = [
  '一号监测点现在的环境数据怎么样？',
  '未来 6 小时土壤湿度如何变化？',
  '番茄花期应该怎么浇水？',
  '帮我查一下灌溉记录',
]

function AssistantMessage({ msg }: { msg: ChatMessage }) {
  return (
    <div className="chat-bubble-assistant">
      {msg.content || (msg.status === 'streaming' ? '正在思考…' : '')}
      <AgentTimeline items={msg.traces} />
      {msg.approval && <ApprovalCard messageId={msg.id} approval={msg.approval} />}
      {msg.status === 'error' && (
        <Typography.Text type="danger">出错了：{msg.error}</Typography.Text>
      )}
    </div>
  )
}

export default function ChatPage() {
  const sessionId = useChatStore((s) => s.sessionId)
  const messages = useChatStore((s) => s.messages)
  const newSession = useChatStore((s) => s.newSession)
  const sendMessage = useChatStore((s) => s.sendMessage)
  const scrollRef = useRef<HTMLDivElement>(null)

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' })
  }, [messages])

  return (
    <div
      style={{
        height: '100%',
        display: 'flex',
        flexDirection: 'column',
        maxWidth: 960,
        margin: '0 auto',
        gap: 12,
      }}
    >
      <div
        style={{
          background: '#fff',
          borderRadius: 10,
          padding: '12px 20px',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
        }}
      >
        <Typography.Title level={4} style={{ margin: 0 }}>
          AI 对话助手
        </Typography.Title>
        <Space>
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            会话：{sessionId.slice(0, 12)}
          </Typography.Text>
          <Button icon={<PlusOutlined />} onClick={newSession}>
            新会话
          </Button>
        </Space>
      </div>

      <div
        ref={scrollRef}
        className="chat-scroll"
        style={{
          flex: 1,
          overflowY: 'auto',
          background: '#fff',
          borderRadius: 10,
          padding: 20,
        }}
      >
        {messages.length === 0 ? (
          <Empty
            style={{ marginTop: 100 }}
            description={
              <>
                <div>我是智慧农业 AI 助手，可以帮你：</div>
                <div style={{ fontSize: 12, color: '#999', marginTop: 8 }}>
                  查询环境与设备状态 · 回答种植和病虫害问题 · 预测土壤湿度 ·
                  执行灌溉和设备开关（高危操作会先请你确认）
                </div>
              </>
            }
          >
            <Space wrap>
              {SUGGESTIONS.map((s) => (
                <Button key={s} size="small" onClick={() => void sendMessage(s)}>
                  {s}
                </Button>
              ))}
            </Space>
          </Empty>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 18 }}>
            {messages.map((msg) => (
              <div
                key={msg.id}
                style={{
                  display: 'flex',
                  justifyContent: msg.role === 'user' ? 'flex-end' : 'flex-start',
                  gap: 10,
                }}
              >
                {msg.role === 'assistant' && (
                  <RobotOutlined style={{ marginTop: 12, color: '#3f7a3d' }} />
                )}
                {msg.role === 'user' ? (
                  <div className="chat-bubble-user">{msg.content}</div>
                ) : (
                  <AssistantMessage msg={msg} />
                )}
                {msg.role === 'user' && <UserOutlined style={{ marginTop: 12 }} />}
              </div>
            ))}
          </div>
        )}
      </div>

      <div style={{ background: '#fff', borderRadius: 10, padding: 12 }}>
        <ChatInput />
      </div>
    </div>
  )
}
