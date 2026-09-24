import { Alert, Button, Descriptions, Space, Tag } from 'antd'
import { ExclamationCircleFilled } from '@ant-design/icons'
import type { ApprovalInfo } from '../../stores/chatStore'
import { useChatStore } from '../../stores/chatStore'
import { toolLabel } from '../../utils/constants'

interface Props {
  messageId: number
  approval: ApprovalInfo
}

/** 高危操作确认卡片：用户确认/拒绝后调用 /api/chat/resume 恢复执行 */
export default function ApprovalCard({ messageId, approval }: Props) {
  const sending = useChatStore((s) => s.sending)
  const resolveApproval = useChatStore((s) => s.resolveApproval)

  const statusTag =
    approval.status === 'approved' ? (
      <Tag color="green">已确认执行</Tag>
    ) : approval.status === 'rejected' ? (
      <Tag color="red">已拒绝</Tag>
    ) : (
      <Tag color="orange">等待确认</Tag>
    )

  const argEntries = Object.entries(approval.args || {})

  return (
    <Alert
      style={{ marginTop: 10, alignItems: 'flex-start' }}
      type="warning"
      showIcon
      icon={<ExclamationCircleFilled />}
      message={
        <Space size={8} wrap>
          <strong>高危操作需要确认</strong>
          {statusTag}
        </Space>
      }
      description={
        <div>
          <p style={{ margin: '4px 0 8px' }}>{approval.summary}</p>
          {argEntries.length > 0 && (
            <Descriptions
              size="small"
              column={1}
              bordered
              items={argEntries.map(([k, v]) => ({
                key: k,
                label: k,
                children: String(v ?? '-'),
              }))}
              style={{ marginBottom: 10 }}
            />
          )}
          {approval.status === 'pending' && (
            <Space>
              <Button
                type="primary"
                danger
                loading={sending}
                onClick={() => resolveApproval(messageId, true)}
              >
                确认执行
              </Button>
              <Button disabled={sending} onClick={() => resolveApproval(messageId, false)}>
                拒绝
              </Button>
              <span style={{ color: '#999', fontSize: 12 }}>
                工具：{toolLabel(approval.tool)}
              </span>
            </Space>
          )}
        </div>
      }
    />
  )
}
