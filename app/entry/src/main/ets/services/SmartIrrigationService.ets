import { HttpClient } from '../web/HttpClient'
import { EnvironmentData } from '../models/EnvironmentData'
import { IrrigationThresholdConfig } from '../models/Irrigation'

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
  cropCode?: string
  cropName?: string
  currentStage?: string
  daysSincePlanting?: number
  minHumidity?: number
  maxHumidity?: number
  optimalHumidity?: number
  irrigationFactor?: number
  frequencyHint?: string
  waterNeeds?: string
  specialNotes?: string
  hasCropConfig?: boolean
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
 * 多目标优化结果
 */
export interface OptimizationResult {
  waterAmount: number           // 推荐用水量(L)
  durationSeconds: number       // 灌溉时长(秒)
  estimatedMoistureGain: number // 预计湿度提升
  predictedMoisture: number     // 预测灌溉后湿度
  cost: number                  // 预估成本
  healthScore: number           // 作物健康得分
  totalScore: number            // 综合得分
  paretoRank: number            // 帕累托等级
}

/**
 * 优化算法信息
 */
export interface OptimizationInfo {
  name: string
  description: string
  objectives: { [key: string]: string }
  parameters: { [key: string]: number }
}

/**
 * LSTM模型信息
 */
export interface LSTMModelInfo {
  mode: string
  modelLoaded: boolean
  modelPath: string
  seqLength: number
  featureSize: number
  predictHours: number[]
}

/**
 * 算法对比结果
 */
export interface AlgorithmCompare {
  ewma: {
    name: string
    description: string
    status: string
  }
  multiObjective: {
    name: string
    description: string
    status: string
    result?: OptimizationResult
  }
  lstm: {
    name: string
    description: string
    modelLoaded: boolean
    status: string
  }
}

/**
 * 智能灌溉统计
 */
export interface SmartIrrigationStats {
  learningProgress: LearningProgress
  cropStrategy: IrrigationStrategy
  recentDecisions: IrrigationThresholdConfig[]
}

/**
 * 智能灌溉服务
 * 提供预测性灌溉、自适应学习、作物生长阶段感知功能
 * 支持多目标优化和LSTM深度学习
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

  // ========== 多目标优化接口 ==========

  /**
   * 执行多目标优化
   */
  async optimizeIrrigation(
    currentMoisture: number,
    targetMoisture: number,
    temperature: number = 25,
    currentHour: number = 14,
    cropFactor: number = 1.0
  ): Promise<{ optimization: OptimizationResult, algorithm: OptimizationInfo }> {
    try {
      const result = await HttpClient.get<ApiResponse<{ optimization: OptimizationResult, algorithm: OptimizationInfo }>>(
        `/api/test/smart-irrigation/optimization?currentMoisture=${currentMoisture}&targetMoisture=${targetMoisture}&temperature=${temperature}&currentHour=${currentHour}&cropFactor=${cropFactor}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 多目标优化失败:', error)
      return {
        optimization: this.getDefaultOptimization(),
        algorithm: this.getDefaultOptimizationInfo()
      }
    }
  }

  /**
   * 获取优化算法信息
   */
  async getOptimizationInfo(): Promise<OptimizationInfo> {
    try {
      const result = await HttpClient.get<ApiResponse<OptimizationInfo>>(
        '/api/test/smart-irrigation/optimization/info'
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 获取优化信息失败:', error)
      return this.getDefaultOptimizationInfo()
    }
  }

  // ========== LSTM/ONNX 接口 ==========

  /**
   * 获取LSTM模型信息
   */
  async getLSTMModelInfo(pointId: number = 1): Promise<LSTMModelInfo & { predictions?: { [key: string]: number } }> {
    try {
      const result = await HttpClient.get<ApiResponse<LSTMModelInfo & { predictions?: { [key: string]: number } }>>(
        `/api/test/smart-irrigation/lstm?pointId=${pointId}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 获取LSTM信息失败:', error)
      return {
        mode: 'ewma',
        modelLoaded: false,
        modelPath: '',
        seqLength: 24,
        featureSize: 5,
        predictHours: [2, 4, 6]
      }
    }
  }

  /**
   * 获取算法对比报告
   */
  async compareAlgorithms(
    currentMoisture: number = 35,
    targetMoisture: number = 55
  ): Promise<AlgorithmCompare> {
    try {
      const result = await HttpClient.get<ApiResponse<AlgorithmCompare>>(
        `/api/test/smart-irrigation/compare?currentMoisture=${currentMoisture}&targetMoisture=${targetMoisture}`
      )
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 算法对比失败:', error)
      return {
        ewma: { name: 'EWMA', description: '指数加权移动平均', status: '已实现' },
        multiObjective: { name: 'NSGA-II', description: '多目标遗传算法', status: '已实现' },
        lstm: { name: 'LSTM', description: '深度学习预测', modelLoaded: false, status: '待训练' }
      }
    }
  }

  /**
   * 测试全部算法
   */
  async testAllAlgorithms(pointId: number = 1): Promise<{
    prediction: MoisturePrediction
    learning: LearningProgress
    cropStrategy: IrrigationStrategy
    irrigationPlan: SmartIrrigationPlan
  }> {
    try {
      const result = await HttpClient.get<ApiResponse<{
        prediction: MoisturePrediction
        learning: LearningProgress
        cropStrategy: IrrigationStrategy
        irrigationPlan: SmartIrrigationPlan
      }>>(`/api/test/smart-irrigation/all?pointId=${pointId}`)
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 测试全部算法失败:', error)
      return {
        prediction: this.getDefaultPrediction(),
        learning: {},
        cropStrategy: this.getDefaultStrategy(),
        irrigationPlan: this.getDefaultPlan()
      }
    }
  }

  /**
   * 模拟智能灌溉
   */
  async simulateIrrigation(pointId: number, soilMoistureBefore: number = 35): Promise<{
    plan: SmartIrrigationPlan
    irrigationLog: any
    simulatedMoistureAfter: number
    updatedLearning: LearningProgress
    message: string
  }> {
    try {
      const result = await HttpClient.post<ApiResponse<{
        plan: SmartIrrigationPlan
        irrigationLog: any
        simulatedMoistureAfter: number
        updatedLearning: LearningProgress
        message: string
      }>>(`/api/test/smart-irrigation/simulate?pointId=${pointId}&soilMoistureBefore=${soilMoistureBefore}`, {})
      return result.data
    } catch (error) {
      console.error('[SmartIrrigationService] 模拟灌溉失败:', error)
      throw error
    }
  }

  // ========== 默认值 ==========

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
      cropCode: '',
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

  private getDefaultOptimization(): OptimizationResult {
    return {
      waterAmount: 10,
      durationSeconds: 20,
      estimatedMoistureGain: 15,
      predictedMoisture: 50,
      cost: 0.1,
      healthScore: 80,
      totalScore: 0.75,
      paretoRank: 0
    }
  }

  private getDefaultOptimizationInfo(): OptimizationInfo {
    return {
      name: 'NSGA-II 多目标遗传算法',
      description: '在节水、成本、作物健康间寻找帕累托最优解',
      objectives: {
        moistureScore: '湿度达标率',
        waterScore: '节水量',
        costScore: '经济成本',
        healthScore: '作物健康'
      },
      parameters: {
        populationSize: 50,
        maxGenerations: 100,
        mutationRate: 0.1,
        crossoverRate: 0.8
      }
    }
  }
}