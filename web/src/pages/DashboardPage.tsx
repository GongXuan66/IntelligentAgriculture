import { useEffect, useState } from 'react'
import { Card, Col, Row, Statistic, Tabs } from 'antd'
import { getCurrentEnvironment, getEnvironmentHistory } from '../api/business'
import type { EnvironmentData } from '../api/types'
import TrendChart from '../components/TrendChart'
import PointSelector from '../components/PointSelector'
import { useAppStore } from '../stores/appStore'

const METRICS = [
  { key: 'temperature', label: '空气温度', unit: '℃', color: '#fa8c16' },
  { key: 'humidity', label: '空气湿度', unit: '%', color: '#1890ff' },
  { key: 'light', label: '光照强度', unit: 'lux', color: '#fadb14' },
  { key: 'co2', label: 'CO₂ 浓度', unit: 'ppm', color: '#722ed1' },
  { key: 'soilMoisture', label: '土壤湿度', unit: '%', color: '#52c41a' },
] as const

type MetricKey = (typeof METRICS)[number]['key']

export default function DashboardPage() {
  const pointId = useAppStore((s) => s.pointId)
  const loadPoints = useAppStore((s) => s.loadPoints)
  const [current, setCurrent] = useState<EnvironmentData | null>(null)
  const [history, setHistory] = useState<EnvironmentData[]>([])
  const [metric, setMetric] = useState<MetricKey>('soilMoisture')

  useEffect(() => {
    void loadPoints()
  }, [loadPoints])

  useEffect(() => {
    let mounted = true
    const load = () => {
      getCurrentEnvironment(pointId)
        .then((d) => mounted && setCurrent(d))
        .catch(() => {})
      getEnvironmentHistory(pointId, 48)
        .then((list) => mounted && setHistory([...list].reverse()))
        .catch(() => {})
    }
    load()
    const timer = setInterval(load, 30_000)
    return () => {
      mounted = false
      clearInterval(timer)
    }
  }, [pointId])

  const activeMeta = METRICS.find((m) => m.key === metric)!

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
        <PointSelector />
      </div>

      <Row gutter={[12, 12]}>
        {METRICS.map((m) => (
          <Col xs={12} sm={8} md={4} key={m.key}>
            <Card
              size="small"
              hoverable
              onClick={() => setMetric(m.key)}
              style={metric === m.key ? { borderColor: m.color } : undefined}
            >
              <Statistic
                title={m.label}
                value={current ? Number(current[m.key]) : '--'}
                suffix={m.unit}
                valueStyle={{ color: m.color, fontSize: 22 }}
              />
            </Card>
          </Col>
        ))}
      </Row>

      <Card
        style={{ marginTop: 12 }}
        size="small"
        title={`${activeMeta.label}历史趋势（最近 ${history.length} 条）`}
        extra={
          <span style={{ fontSize: 12, color: '#999' }}>
            {current?.recordedAt ? `更新于 ${current.recordedAt.replace('T', ' ')}` : ''}
          </span>
        }
      >
        <Tabs
          activeKey={metric}
          onChange={(k) => setMetric(k as MetricKey)}
          items={METRICS.map((m) => ({ key: m.key, label: m.label }))}
          tabBarStyle={{ marginBottom: 8 }}
        />
        {history.length > 0 ? (
          <TrendChart
            points={history.map((d) => ({
              label: d.recordedAt?.slice(11, 16) ?? '',
              value: Number(d[metric]) || 0,
            }))}
            color={activeMeta.color}
            unit={activeMeta.unit}
            height={200}
          />
        ) : (
          <div style={{ color: '#999', textAlign: 'center', padding: 24 }}>
            暂无历史数据（确认 IA-server 已启动且该监测点有数据上报）
          </div>
        )}
      </Card>
    </div>
  )
}
