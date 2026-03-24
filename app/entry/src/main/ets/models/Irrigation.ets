/**
 * 灌溉记录模型
 */
export class IrrigationRecord {
  id: string = ''
  pointId?: number
  startTime: string = ''
  endTime: string = ''
  duration: number = 0          // 灌溉时长（秒）
  waterAmount: number = 0       // 用水量（升）
  mode: IrrigationMode = IrrigationMode.MANUAL
  
  // 决策相关字段
  decisionType?: string         // 决策类型: predictive/adaptive/stage_based/manual
  currentMoisture?: number      // 决策时湿度
  predictedMoisture?: number    // 预测湿度
  predictionHours?: number      // 预测时长(小时)
  cropStage?: string            // 作物生长阶段
  irrigationFactor?: number     // 灌溉系数
  confidence?: number           // 决策置信度
  
  // 灌溉效果
  soilMoistureBefore: number = 0
  soilMoistureAfter: number = 0
  temperature?: number          // 灌溉时温度
  humidity?: number             // 灌溉时空气湿度
  triggerReason?: string        // 触发原因
}

/**
 * 灌溉模式
 */
export enum IrrigationMode {
  AUTO = '自动灌溉',
  MANUAL = '手动灌溉'
}

/**
 * 决策类型
 */
export enum DecisionType {
  PREDICTIVE = 'predictive',    // 预测性灌溉
  ADAPTIVE = 'adaptive',        // 自适应灌溉
  STAGE_BASED = 'stage_based',  // 基于生长阶段
  STANDARD = 'standard',        // 标准灌溉
  MANUAL = 'manual'             // 手动灌溉
}

/**
 * 决策类型显示名称
 */
export const DecisionTypeNames: Record<string, string> = {
  'predictive': '预测性灌溉',
  'adaptive': '自适应灌溉',
  'stage_based': '阶段感知灌溉',
  'standard': '标准灌溉',
  'manual': '手动灌溉'
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

/**
 * 灌溉阈值配置
 */
export class IrrigationThresholdConfig {
  id?: number
  pointId?: number
  moistureThreshold?: number         // 湿度阈值(%)
  maxSingleIrrigation?: number       // 单次最大灌溉时长(秒)
  minIrrigationInterval?: number     // 最小灌溉间隔(分钟)
  enablePredictive?: number          // 启用预测灌溉
  enableAutoControl?: number         // 启用自动控制
  predictionMode?: string            // 预测模式: ewma/lstm
  learnedMoistureGain?: number       // 学习到的湿度提升率
  learningSampleCount?: number       // 学习样本数
  learningConfidence?: number        // 学习置信度
  lastLearningAt?: string            // 最后学习时间
}