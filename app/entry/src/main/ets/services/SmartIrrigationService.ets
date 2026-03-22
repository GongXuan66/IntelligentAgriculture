import { HttpClient } from '../web/HttpClient'
import { EnvironmentData } from '../models/EnvironmentData'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 湿度预测结果
 */
export interface MoisturePrediction {
  currentMoisture: number
  predict2h: number
  predict4h: number
  predict6h: number
  trend: string  // rising/falling/stable
  needPreIrrigation: boolean
  reason: string
  confidence: number
}

/**
 * 灌溉策略（基于作物生长阶段）
 */
export interface IrrigationStrategy {
  cropType: string
  cropName: string
  currentStage: string
  daysSincePlanting: number
  minHumidity: number
  maxHumidity: number
  optimalHumidity: number
  irrigationFactor: number
  frequencyHint: string
  waterNeeds: string
  specialNotes: string
  hasCropConfig: boolean
}

/**
 * 智能灌溉计划
 */
export interface SmartIrrigationPlan {
  shouldIrrigate: boolean
  decisionType: string  // predictive/adaptive/stage_based/standard
  waterAmountL: number
  durationSeconds: number
  targetMoisture: number
  currentMoisture: number
  predictedMoisture: number
  irrigationFactor: number
  cropStage: string
  reason: string
  confidence: number
  predictionMode: string  // standard/ewma/lstm
}

/**
 * 学习参数
 */
export interface LearningParam {
  value: number
  confidence: number
  sampleCount: number
}

/**
 * 学习进度
 */
export interface LearningProgress {
  [key: string]: LearningParam
}

/**
 * 作物类型
 */
export interface CropType {
  type: string
  name: string
}

/**
 * 设置作物请求
 */
export interface SetCropRequest {
  cropType: string
  cropName: string
  plantingDate: string
}

/**
 * 智能灌溉服务
 * 提供预测性灌溉、自适应学习、作物生长阶段感知功能
 */
export class SmartIrrigationService {

  /**
   * 获取智能灌溉计划
   */
  async getSmartPlan(pointId: number, envData: EnvironmentData | null): Promise<SmartIrrigationPlan> {
    try {
      const result = await HttpClient.post<ApiResponse<SmartIrrigationPlan>>(
        `/api/smart-irrigation/plan?pointId=${pointId}`,
        { envData, config: null }
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 获取智能计划失败:', error)
      return this.getDefaultPlan()
    }
  }

  /**
   * 执行智能灌溉
   */
  async executeSmartIrrigation(pointId: number, envData: EnvironmentData | null): Promise<SmartIrrigationPlan> {
    try {
      const result = await HttpClient.post<ApiResponse<SmartIrrigationPlan>>(
        `/api/smart-irrigation/execute?pointId=${pointId}`,
        { envData, config: null }
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 执行智能灌溉失败:', error)
      throw error
    }
  }

  /**
   * 获取湿度预测
   */
  async getMoisturePrediction(pointId: number, hoursAhead: number = 4): Promise<MoisturePrediction> {
    try {
      const result = await HttpClient.get<ApiResponse<MoisturePrediction>>(
        `/api/smart-irrigation/predict?pointId=${pointId}&hoursAhead=${hoursAhead}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 获取预测失败:', error)
      return this.getDefaultPrediction()
    }
  }

  /**
   * 分析是否需要预防性灌溉
   */
  async analyzePrediction(pointId: number, threshold: number = 40): Promise<MoisturePrediction> {
    try {
      const result = await HttpClient.get<ApiResponse<MoisturePrediction>>(
        `/api/smart-irrigation/predict/analyze?pointId=${pointId}&threshold=${threshold}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 分析预测失败:', error)
      return this.getDefaultPrediction()
    }
  }

  /**
   * 获取学习进度
   */
  async getLearningProgress(pointId: number): Promise<LearningProgress> {
    try {
      const result = await HttpClient.get<ApiResponse<LearningProgress>>(
        `/api/smart-irrigation/learning/progress?pointId=${pointId}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 获取学习进度失败:', error)
      return {}
    }
  }

  /**
   * 获取灌溉策略
   */
  async getIrrigationStrategy(pointId: number): Promise<IrrigationStrategy> {
    try {
      const result = await HttpClient.get<ApiResponse<IrrigationStrategy>>(
        `/api/smart-irrigation/strategy?pointId=${pointId}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 获取灌溉策略失败:', error)
      return this.getDefaultStrategy()
    }
  }

  /**
   * 设置作物信息
   */
  async setCrop(pointId: number, cropType: string, cropName: string, plantingDate: string): Promise<void> {
    try {
      await HttpClient.post<ApiResponse<void>>(
        `/api/smart-irrigation/crop?pointId=${pointId}`,
        { cropType, cropName, plantingDate }
      )
    } catch (error) {
      console.error('[SmartIrrigationService] 设置作物失败:', error)
      throw error
    }
  }

  /**
   * 收获作物
   */
  async harvestCrop(pointId: number): Promise<void> {
    try {
      await HttpClient.delete<ApiResponse<void>>(
        `/api/smart-irrigation/crop?pointId=${pointId}`
      )
    } catch (error) {
      console.error('[SmartIrrigationService] 收获作物失败:', error)
    }
  }

  /**
   * 获取支持的作物类型
   */
  async getSupportedCropTypes(): Promise<CropType[]> {
    try {
      const result = await HttpClient.get<ApiResponse<{ [key: string]: string }>>(
        '/api/smart-irrigation/crop/types'
      )
      const types: CropType[] = []
      for (const [type, name] of Object.entries(result.data)) {
        types.push({ type, name })
      }
      return types
    } catch (error) {
      console.error('[SmartIrrigationService] 获取作物类型失败:', error)
      return [
        { type: 'tomato', name: '番茄' },
        { type: 'cucumber', name: '黄瓜' },
        { type: 'pepper', name: '辣椒' },
        { type: 'vegetable', name: '蔬菜' }
      ]
    }
  }

  /**
   * 灌溉完成回调
   */
  async onIrrigationComplete(logId: number, soilMoistureAfter: number): Promise<void> {
    try {
      await HttpClient.post<ApiResponse<void>>(
        `/api/smart-irrigation/complete/${logId}?soilMoistureAfter=${soilMoistureAfter}`,
        {}
      )
    } catch (error) {
      console.error('[SmartIrrigationService] 完成回调失败:', error)
    }
  }

  // 默认值

  private getDefaultPlan(): SmartIrrigationPlan {
    return {
      shouldIrrigate: false,
      decisionType: 'standard',
      waterAmountL: 0,
      durationSeconds: 0,
      targetMoisture: 52,
      currentMoisture: 0,
      predictedMoisture: 0,
      irrigationFactor: 1,
      cropStage: '',
      reason: '无法获取智能灌溉计划',
      confidence: 0,
      predictionMode: 'standard'
    }
  }

  private getDefaultPrediction(): MoisturePrediction {
    return {
      currentMoisture: 0,
      predict2h: 0,
      predict4h: 0,
      predict6h: 0,
      trend: 'stable',
      needPreIrrigation: false,
      reason: '无法获取预测数据',
      confidence: 0
    }
  }

  private getDefaultStrategy(): IrrigationStrategy {
    return {
      cropType: '',
      cropName: '',
      currentStage: '',
      daysSincePlanting: 0,
      minHumidity: 40,
      maxHumidity: 75,
      optimalHumidity: 52,
      irrigationFactor: 1,
      frequencyHint: '根据环境自动调整',
      waterNeeds: '',
      specialNotes: '',
      hasCropConfig: false
    }
  }
}
