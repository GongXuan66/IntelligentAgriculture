import { useState } from 'react'
import { Button, Input, Space } from 'antd'
import { SendOutlined, StopOutlined } from '@ant-design/icons'
import { useChatStore } from '../../stores/chatStore'

export default function ChatInput() {
  const [value, setValue] = useState('')
  const sending = useChatStore((s) => s.sending)
  const sendMessage = useChatStore((s) => s.sendMessage)
  const stopStreaming = useChatStore((s) => s.stopStreaming)

  const submit = () => {
    if (!value.trim() || sending) return
    void sendMessage(value)
    setValue('')
  }

  return (
    <Space.Compact style={{ width: '100%' }}>
      <Input.TextArea
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder="向 AI 助手提问，例如：1号棚现在温度多少？/ 番茄苗期怎么浇水？"
        autoSize={{ minRows: 1, maxRows: 4 }}
        onPressEnter={(e) => {
          if (!e.shiftKey) {
            e.preventDefault()
            submit()
          }
        }}
      />
      {sending ? (
        <Button danger icon={<StopOutlined />} onClick={stopStreaming} style={{ height: 'auto' }}>
          停止
        </Button>
      ) : (
        <Button
          type="primary"
          icon={<SendOutlined />}
          disabled={!value.trim()}
          onClick={submit}
          style={{ height: 'auto' }}
        >
          发送
        </Button>
      )}
    </Space.Compact>
  )
}
