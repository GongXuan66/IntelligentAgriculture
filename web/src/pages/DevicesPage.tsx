import { useEffect, useState } from 'react'
import { Button, Card, Col, Popconfirm, Row, Typography, message } from 'antd'
import { ReloadOutlined } from '@ant-design/icons'
import { controlDevice, getDevices } from '../api/business'
import type { Device } from '../api/types'
import { DEVICE_STATUS_MAP, renderStatusTag } from '../utils/constants'

const DEVICE_TYPE_ICON: Record<string, string> = {
  fan: '🌀',
  pump: '💧',
  light: '💡',
  curtain: '🪟',
  sensor: '📡',
}

/** 在线/工作中视为运行态，可下发关闭；离线/故障只能尝试开启 */
function isRunning(status: number) {
  return status === 1 || status === 2
}

export default function DevicesPage() {
  const [devices, setDevices] = useState<Device[]>([])
  const [loading, setLoading] = useState(false)
  const [operating, setOperating] = useState<string | null>(null)

  const load = () => {
    setLoading(true)
    getDevices()
      .then(setDevices)
      .catch((e) => message.error(`加载设备失败：${e.message}`))
      .finally(() => setLoading(false))
  }

  useEffect(load, [])

  const toggle = async (device: Device) => {
    const command = isRunning(device.status) ? 'off' : 'on'
    setOperating(device.deviceCode)
    try {
      await controlDevice(device.deviceCode, command)
      message.success(`${device.deviceName} ${command === 'on' ? '已开启' : '已关闭'}`)
      load()
    } catch (e) {
      message.error(`控制失败：${e instanceof Error ? e.message : e}`)
    } finally {
      setOperating(null)
    }
  }

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
        <Button icon={<ReloadOutlined />} onClick={load} loading={loading}>
          刷新
        </Button>
      </div>
      <Row gutter={[12, 12]}>
        {devices.map((d) => (
          <Col xs={24} sm={12} md={8} lg={6} key={d.id}>
            <Card
              size="small"
              title={
                <>
                  <span style={{ marginRight: 8 }}>
                    {DEVICE_TYPE_ICON[d.deviceType] ?? '🔌'}
                  </span>
                  {d.deviceName}
                </>
              }
              extra={renderStatusTag(DEVICE_STATUS_MAP, d.status)}
            >
              <Typography.Paragraph type="secondary" style={{ fontSize: 12, marginBottom: 8 }}>
                编码：{d.deviceCode}
                <br />
                类型：{d.deviceType}　监测点：{d.pointId}
                {d.lastHeartbeat && (
                  <>
                    <br />
                    心跳：{d.lastHeartbeat.replace('T', ' ')}
                  </>
                )}
              </Typography.Paragraph>
              <Popconfirm
                title={`确认${isRunning(d.status) ? '关闭' : '开启'} ${d.deviceName}？`}
                onConfirm={() => toggle(d)}
              >
                <Button
                  size="small"
                  type={isRunning(d.status) ? 'default' : 'primary'}
                  danger={isRunning(d.status)}
                  loading={operating === d.deviceCode}
                  block
                >
                  {isRunning(d.status) ? '关闭' : '开启'}
                </Button>
              </Popconfirm>
            </Card>
          </Col>
        ))}
        {devices.length === 0 && !loading && (
          <Col span={24} style={{ textAlign: 'center', color: '#999', padding: 40 }}>
            暂无设备（确认 IA-server 已启动）
          </Col>
        )}
      </Row>
    </div>
  )
}
