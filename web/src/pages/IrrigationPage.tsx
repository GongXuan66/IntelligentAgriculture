import { useEffect, useState } from 'react'
import {
  Alert,
  Button,
  Card,
  Col,
  Descriptions,
  Popconfirm,
  Row,
  Space,
  Statistic,
  Table,
  Tag,
  message,
} from 'antd'
import { ReloadOutlined } from '@ant-design/icons'
import {
  getIrrigationLogs,
  getIrrigationStrategy,
  getIrrigationTotal,
  getMoisturePrediction,
  getSmartPlan,
  startIrrigation,
  stopIrrigation,
} from '../api/business'
import type {
  IrrigationLog,
  IrrigationStrategy,
  MoisturePrediction,
  SmartIrrigationPlan,
} from '../api/types'
import TrendChart from '../components/TrendChart'
import PointSelector from '../components/PointSelector'
import { useAppStore } from '../stores/appStore'
import { DECISION_TYPE_MAP, IRRIGATION_MODE_MAP, TREND_MAP } from '../utils/constants'

export default function IrrigationPage() {
  const pointId = useAppStore((s) => s.pointId)
  const loadPoints = useAppStore((s) => s.loadPoints)
  const [prediction, setPrediction] = useState<MoisturePrediction | null>(null)
  const [plan, setPlan] = useState<SmartIrrigationPlan | null>(null)
  const [strategy, setStrategy] = useState<IrrigationStrategy | null>(null)
  const [totalWater, setTotalWater] = useState<number | null>(null)
  const [logs, setLogs] = useState<IrrigationLog[]>([])
  const [operating, setOperating] = useState(false)

  useEffect(() => {
    void loadPoints()
  }, [loadPoints])

  const load = () => {
    getMoisturePrediction(pointId)
      .then(setPrediction)
      .catch(() => setPrediction(null))
    getSmartPlan(pointId)
      .then(setPlan)
      .catch(() => setPlan(null))
    getIrrigationStrategy(pointId)
      .then(setStrategy)
      .catch(() => setStrategy(null))
    getIrrigationTotal(pointId)
      .then((n) => setTotalWater(Number(n)))
      .catch(() => setTotalWater(null))
    getIrrigationLogs(pointId)
      .then(setLogs)
      .catch(() => setLogs([]))
  }

  useEffect(load, [pointId])

  const handleStart = async () => {
    setOperating(true)
    try {
      await startIrrigation(pointId, 60, 1)
      message.success('灌溉已启动')
      load()
    } catch (e) {
      message.error(`启动失败：${e instanceof Error ? e.message : e}`)
    } finally {
      setOperating(false)
    }
  }

  const handleStop = async (logId: number) => {
    setOperating(true)
    try {
      await stopIrrigation(logId)
      message.success('灌溉已停止')
      load()
    } catch (e) {
      message.error(`停止失败：${e instanceof Error ? e.message : e}`)
    } finally {
      setOperating(false)
    }
  }

  const predictionPoints = prediction
    ? [
        { label: '当前', value: Number(prediction.currentMoisture) },
        { label: '+2h', value: Number(prediction.predict2h) },
        { label: '+4h', value: Number(prediction.predict4h) },
        { label: '+6h', value: Number(prediction.predict6h) },
      ]
    : []

  const trendMeta = prediction ? TREND_MAP[prediction.trend] : undefined

  return (
    <div>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
        <Space>
          <Popconfirm title={`确认在监测点 ${pointId} 开始灌溉（60 秒）？`} onConfirm={handleStart}>
            <Button type="primary" loading={operating}>
              开始灌溉
            </Button>
          </Popconfirm>
          <Button icon={<ReloadOutlined />} onClick={load}>
            刷新
          </Button>
        </Space>
        <PointSelector />
      </div>

      <Row gutter={[12, 12]}>
        <Col xs={24} md={10}>
          <Card size="small" title="土壤湿度预测（LSTM）">
            {prediction ? (
              <>
                <Statistic
                  title="当前土壤湿度"
                  value={Number(prediction.currentMoisture)}
                  suffix="%"
                  valueStyle={{ fontSize: 28 }}
                />
                <TrendChart points={predictionPoints} unit="%" height={140} />
                <div style={{ marginTop: 8, fontSize: 13 }}>
                  趋势：
                  <Tag color={trendMeta?.color ?? 'default'}>
                    {trendMeta?.text ?? prediction.trend}
                  </Tag>
                  置信度：{Number(prediction.confidence ?? 0).toFixed(2)}
                </div>
              </>
            ) : (
              <div style={{ color: '#999', padding: 24, textAlign: 'center' }}>
                预测服务不可用（确认 IA-server 已加载 ONNX 模型）
              </div>
            )}
          </Card>

          {totalWater != null && (
            <Card size="small" style={{ marginTop: 12 }}>
              <Statistic title="累计灌溉水量" value={totalWater} suffix="L" />
            </Card>
          )}
        </Col>

        <Col xs={24} md={14}>
          {plan && (
            <Alert
              type={plan.shouldIrrigate ? 'warning' : 'success'}
              showIcon
              style={{ marginBottom: 12 }}
              message={
                <>
                  {plan.shouldIrrigate ? '智能决策：建议灌溉' : '智能决策：暂不灌溉'}
                  <Tag style={{ marginLeft: 8 }} color="blue">
                    {DECISION_TYPE_MAP[plan.decisionType] ?? plan.decisionType}
                  </Tag>
                </>
              }
              description={
                <>
                  {plan.reason}
                  {plan.shouldIrrigate && (
                    <div style={{ marginTop: 4, fontSize: 12 }}>
                      建议水量 {plan.waterAmountL}L / 时长 {plan.durationSeconds}s
                      {plan.cropStage && ` · 生育期：${plan.cropStage}`}
                      {plan.confidence != null && ` · 置信度 ${Number(plan.confidence).toFixed(2)}`}
                    </div>
                  )}
                </>
              }
            />
          )}

          {strategy && Object.keys(strategy).length > 0 && (
            <Card size="small" title="智能灌溉策略" style={{ marginBottom: 12 }}>
              <Descriptions
                size="small"
                column={2}
                items={Object.entries(strategy).map(([k, v]) => ({
                  key: k,
                  label: k,
                  children: String(v ?? '-'),
                }))}
              />
            </Card>
          )}

          <Card size="small" title="灌溉记录">
            <Table<IrrigationLog>
              rowKey="id"
              size="small"
              dataSource={logs}
              pagination={{ pageSize: 8 }}
              columns={[
                { title: 'ID', dataIndex: 'id', width: 60 },
                { title: '监测点', dataIndex: 'pointId', width: 70 },
                {
                  title: '模式',
                  dataIndex: 'mode',
                  width: 70,
                  render: (m: number) => IRRIGATION_MODE_MAP[m] ?? m,
                },
                {
                  title: '决策',
                  dataIndex: 'decisionType',
                  width: 100,
                  render: (t: string) =>
                    t ? (DECISION_TYPE_MAP[t] ?? t) : '--',
                },
                { title: '时长(s)', dataIndex: 'duration', width: 80 },
                {
                  title: '水量(L)',
                  dataIndex: 'waterAmount',
                  width: 80,
                  render: (v: number) => (v != null ? Number(v).toFixed(1) : '--'),
                },
                {
                  title: '灌溉前湿度',
                  dataIndex: 'soilMoistureBefore',
                  width: 100,
                  render: (v: number) => (v != null ? `${Number(v).toFixed(1)}%` : '--'),
                },
                {
                  title: '灌溉后湿度',
                  dataIndex: 'soilMoistureAfter',
                  width: 100,
                  render: (v: number) => (v != null ? `${Number(v).toFixed(1)}%` : '--'),
                },
                {
                  title: '开始时间',
                  dataIndex: 'startTime',
                  render: (t: string) => (t ? t.replace('T', ' ').slice(5, 16) : '--'),
                },
                {
                  title: '操作',
                  width: 80,
                  render: (_, log) =>
                    log.status === 1 || (log.startTime && !log.endTime) ? (
                      <Popconfirm title="确认停止该灌溉？" onConfirm={() => handleStop(log.id)}>
                        <Button size="small" danger>
                          停止
                        </Button>
                      </Popconfirm>
                    ) : (
                      <Tag color="default">已结束</Tag>
                    ),
                },
              ]}
            />
          </Card>
        </Col>
      </Row>
    </div>
  )
}
