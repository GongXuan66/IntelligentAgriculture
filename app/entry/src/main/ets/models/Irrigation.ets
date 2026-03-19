/**
 * 灌溉记录模型
 */
export class IrrigationRecord {
  id: string = ''
  startTime: string = ''
  endTime: string = ''
  duration: number = 0          // 灌溉时长（秒）
  waterAmount: number = 0       // 用水量（升）
  mode: IrrigationMode = IrrigationMode.MANUAL
  soilMoistureBefore: number = 0
  soilMoistureAfter: number = 0
}

/**
 * 灌溉模式
 */
export enum IrrigationMode {
  AUTO = '自动灌溉',
  MANUAL = '手动灌溉'
}

/**
 * 灌溉配置
 */
export class IrrigationConfig {
  autoMode: boolean = true              // 自动模式
  moistureThreshold: number = 40        // 湿度阈值
  irrigationDuration: number = 30       // 灌溉时长（秒）
  minInterval: number = 3600            // 最小间隔（秒）
}
