import { useEffect, useState } from 'react'
import { Button, Card, Input, Modal, Table, message } from 'antd'
import { ReloadOutlined } from '@ant-design/icons'
import { getAlarms, handleAlarm } from '../api/business'
import type { Alarm } from '../api/types'
import { ALARM_LEVEL_MAP, ALARM_STATUS_MAP, renderStatusTag } from '../utils/constants'

export default function AlarmsPage() {
  const [alarms, setAlarms] = useState<Alarm[]>([])
  const [loading, setLoading] = useState(false)
  const [handling, setHandling] = useState<Alarm | null>(null)
  const [remark, setRemark] = useState('')
  const [submitting, setSubmitting] = useState(false)

  const load = () => {
    setLoading(true)
    getAlarms()
      .then(setAlarms)
      .catch((e) => message.error(`加载告警失败：${e.message}`))
      .finally(() => setLoading(false))
  }

  useEffect(load, [])

  const submitHandle = async () => {
    if (!handling) return
    setSubmitting(true)
    try {
      await handleAlarm(handling.id, remark || undefined)
      message.success(`告警 #${handling.id} 已处理`)
      setHandling(null)
      setRemark('')
      load()
    } catch (e) {
      message.error(`处理失败：${e instanceof Error ? e.message : e}`)
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <Card
      size="small"
      title="告警列表"
      extra={
        <Button icon={<ReloadOutlined />} onClick={load} loading={loading}>
          刷新
        </Button>
      }
    >
      <Table<Alarm>
        rowKey="id"
        size="small"
        loading={loading}
        dataSource={alarms}
        pagination={{ pageSize: 10 }}
        columns={[
          { title: 'ID', dataIndex: 'id', width: 60 },
          { title: '监测点', dataIndex: 'pointId', width: 70 },
          { title: '类型', dataIndex: 'alarmType', width: 110 },
          {
            title: '级别',
            dataIndex: 'alarmLevel',
            width: 80,
            render: (lv: number) => renderStatusTag(ALARM_LEVEL_MAP, lv),
          },
          { title: '内容', dataIndex: 'message' },
          {
            title: '数值/阈值',
            width: 120,
            render: (_, a) =>
              a.alarmValue != null && a.threshold != null
                ? `${Number(a.alarmValue)} / ${Number(a.threshold)}`
                : '--',
          },
          {
            title: '状态',
            dataIndex: 'status',
            width: 90,
            render: (s: number) => renderStatusTag(ALARM_STATUS_MAP, s),
          },
          {
            title: '时间',
            dataIndex: 'createdAt',
            width: 140,
            render: (t: string) => (t ? t.replace('T', ' ').slice(5, 16) : '--'),
          },
          {
            title: '操作',
            width: 90,
            render: (_, a) =>
              a.status === 0 ? (
                <Button size="small" type="primary" onClick={() => setHandling(a)}>
                  处理
                </Button>
              ) : (
                <span style={{ fontSize: 12, color: '#999' }}>{a.handleNote || '已处理'}</span>
              ),
          },
        ]}
      />

      <Modal
        title={`处理告警 #${handling?.id}`}
        open={handling !== null}
        onOk={submitHandle}
        onCancel={() => setHandling(null)}
        confirmLoading={submitting}
        okText="确认处理"
        cancelText="取消"
      >
        <p>{handling?.message}</p>
        <Input.TextArea
          value={remark}
          onChange={(e) => setRemark(e.target.value)}
          placeholder="处理备注（可选）"
          rows={3}
        />
      </Modal>
    </Card>
  )
}
