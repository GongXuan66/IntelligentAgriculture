
import { DeviceStatus } from './Device'

/**
 * 环境数据模型
 */
export class EnvironmentData {
  id?: number                   // ID
  pointId?: number              // 检测点ID
  temperature: number = 0       // 温度 ℃
  humidity: number = 0          // 湿度 %
  light: number = 0             // 光照 lux
  co2: number = 0               // CO2 ppm
  soilMoisture: number = 0      // 土壤湿度 %
  recordedAt?: string           // 记录时间（服务端字段）
  timestamp: string = ''        // 时间戳（兼容字段）
  createdAt?: string            // 创建时间
  isConnected?: boolean = true  // 服务器连接状态
}

/**
 * 环境阈值配置
 */
export class EnvironmentThreshold {
  temperatureMax: number = 35   // 温度上限
  temperatureMin: number = 10   // 温度下限
  humidityMax: number = 80      // 湿度上限
  humidityMin: number = 30      // 湿度下限
  lightMin: number = 300        // 光照下限
  co2Max: number = 1000         // CO2上限
  soilMoistureMin: number = 40  // 土壤湿度下限
}
/**
 * 历史数据记录
 * 注意：recordedAt 是服务端返回的字段名，time 是兼容字段
 */
export class HistoryDataRecord {
  id: number = 0
  temperature: number = 0
  humidity: number = 0
  light: number = 0
  co2: number = 0
  soilMoisture: number = 0
  recordedAt: string = ''  // 服务端字段名
  time: string = ''        // 兼容字段
}

/**
 * HTTP响应接口
 */
export interface HttpResponse<T> {
  success: boolean
  data?: T
  message?: string
}

/**
 * 设备状态响应接口
 */
export interface DeviceStatusResponse {
  status: DeviceStatus
}

/**
 * 布尔响应接口
 */
export interface BooleanResponse {
  success: boolean
}
