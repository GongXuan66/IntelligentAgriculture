/** IA-server / IA-AI 接口类型定义（与后端 DTO 对齐） */

/** Java 后端统一响应体 */
export interface ApiResponse<T> {
  code: number
  message: string
  data: T
  timestamp: string
}

export interface MonitorPoint {
  id: number
  farmId: number
  pointCode: string
  pointName: string
  location: string
  area: number
  soilType: string
  status: number
}

export interface Device {
  id: number
  pointId: number
  deviceCode: string
  deviceName: string
  deviceType: string
  deviceModel?: string
  manufacturer?: string
  /** 0=离线/关闭 1=在线/运行（以后端 DeviceStatus 为准） */
  status: number
  lastHeartbeat?: string
}

export interface EnvironmentData {
  id: number
  pointId: number
  temperature: number
  humidity: number
  light: number
  co2: number
  soilMoisture: number
  recordedAt: string
}

export interface Alarm {
  id: number
  pointId: number
  alarmType: string
  alarmLevel: number
  alarmValue: number
  threshold: number
  message: string
  /** 0=未处理 1=已处理 */
  status: number
  handleNote?: string
  handledAt?: string
  createdAt: string
}

export interface IrrigationLog {
  id: number
  pointId: number
  waterAmount: number
  duration: number
  mode: number
  decisionType?: string
  currentMoisture?: number
  predictedMoisture?: number
  predictionHours?: number
  cropStage?: string
  irrigationFactor?: number
  confidence?: number
  soilMoistureBefore?: number
  soilMoistureAfter?: number
  startTime?: string
  endTime?: string
  status?: number
}

export interface MoisturePrediction {
  currentMoisture: number
  predict2h: number
  predict4h: number
  predict6h: number
  trend: string
  needPreIrrigation: boolean
  reason: string
  confidence: number
}

/** 智能灌溉决策方案（POST /smart-irrigation/plan） */
export interface SmartIrrigationPlan {
  shouldIrrigate: boolean
  decisionType: string
  waterAmountL: number
  durationSeconds: number
  targetMoisture: number
  currentMoisture: number
  predictedMoisture: number
  irrigationFactor?: number
  cropStage?: string
  reason?: string
  confidence?: number
  predictionMode?: string
}

/** 灌溉策略（结构由后端策略配置决定，按键值展示） */
export type IrrigationStrategy = Record<string, unknown>

/** ---------- IA-AI SSE 事件 ---------- */

export type SSEEventType =
  | 'token'
  | 'tool_start'
  | 'tool_end'
  | 'expert_handoff'
  | 'rag_retrieve'
  | 'approval_required'
  | 'done'
  | 'error'

export interface SSEEvent {
  event: SSEEventType
  token?: string
  tool?: string
  args?: Record<string, unknown>
  result?: string
  expert?: string
  expert_name?: string
  query?: string
  snippet?: string
  summary?: string
  done?: boolean
  error?: string
  message?: string
}
