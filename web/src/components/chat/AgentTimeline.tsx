import { Tag, Timeline, Typography } from 'antd'
import {
  BookOutlined,
  CheckCircleOutlined,
  LoadingOutlined,
  RobotOutlined,
  ToolOutlined,
} from '@ant-design/icons'
import type { TraceItem } from '../stores/chatStore'

function formatArgs(args?: Record<string, unknown>): string {
  if (!args) return ''
  const entries = Object.entries(args).filter(([, v]) => v !== undefined)
  if (entries.length === 0) return ''
  return entries
    .map(([k, v]) => `${k}=${typeof v === 'object' ? JSON.stringify(v) : String(v)}`)
    .join('，')
}

function iconFor(item: TraceItem) {
  if (item.status === 'running') return <LoadingOutlined style={{ color: '#1677ff' }} />
  if (item.kind === 'expert') return <RobotOutlined style={{ color: '#722ed1' }} />
  if (item.kind === 'rag') return <BookOutlined style={{ color: '#fa8c16' }} />
  return <CheckCircleOutlined style={{ color: '#52c41a' }} />
}

function colorFor(item: TraceItem): string {
  if (item.status === 'running') return 'blue'
  if (item.kind === 'expert') return 'purple'
  if (item.kind === 'rag') return 'orange'
  return 'green'
}

/** Agent 执行轨迹时间线：专家分派 / 工具调用 / RAG 检索（start/end 配对展示） */
export default function AgentTimeline({ items }: { items: TraceItem[] }) {
  if (items.length === 0) return null

  return (
    <div className="trace-block">
      <Typography.Text type="secondary" style={{ fontSize: 12 }}>
        执行轨迹
      </Typography.Text>
      <Timeline
        style={{ marginTop: 8, marginBottom: 0 }}
        items={items.map((item) => ({
          key: item.id,
          color: colorFor(item),
          dot: iconFor(item),
          children: (
            <div>
              <span>
                {item.kind === 'expert' && (
                  <Tag color="purple" style={{ marginRight: 6 }}>
                    专家分派
                  </Tag>
                )}
                {item.kind === 'rag' && (
                  <Tag color="orange" style={{ marginRight: 6 }}>
                    RAG
                  </Tag>
                )}
                {item.kind === 'tool' && (
                  <Tag style={{ marginRight: 6 }}>
                    <ToolOutlined /> 工具
                  </Tag>
                )}
                <strong>{item.label}</strong>
                <Typography.Text type="secondary" style={{ fontSize: 12, marginLeft: 8 }}>
                  {item.time}
                </Typography.Text>
              </span>
              {item.kind === 'expert' && item.args?.query && (
                <div style={{ fontSize: 12, color: '#666' }}>
                  问题：{String(item.args.query)}
                </div>
              )}
              {item.kind !== 'expert' && formatArgs(item.args) && (
                <div style={{ fontSize: 12, color: '#666' }}>
                  参数：{formatArgs(item.args)}
                </div>
              )}
              {item.status === 'done' && item.result && (
                <div className="tool-result-box">{item.result}</div>
              )}
              {item.status === 'running' && (
                <Typography.Text type="secondary" style={{ fontSize: 12 }}>
                  执行中…
                </Typography.Text>
              )}
            </div>
          ),
        }))}
      />
    </div>
  )
}
