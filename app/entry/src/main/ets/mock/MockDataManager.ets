import { EnvironmentData } from '../models/EnvironmentData'
import { AppConfig } from '../config/AppConfig'
import { HttpClient } from '../web/HttpClient'
import { IrrigationCalibration } from '../config/IrrigationCalibration'
/**
 * API响应结构
 */
interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 衰减计算结果
 */
interface DecayResult {
  soilMoistureDecay: number
  humidityDecay: number
}

/**
 * 模拟数据配置
 */
interface MockConfig {
  soilMoistureGainPerLiter: number
  humidityGainPerLiter: number
  maxSoilMoistureGain: number
  maxHumidityGain: number
  lightLuxPerBrightnessPercent: number
  ambientLightDecayPerMinute: number
  ambientRandomRange: number
  lightMin: number
  lightMax: number
  soilMoistureDecayPerMinute: number
  humidityDecayPerMinute: number
  soilMoistureMin: number
  soilMoistureMax: number
  humidityMin: number
  humidityMax: number
  temperatureMin: number
  temperatureMax: number
  co2Min: number
  co2Max: number
}

/**
 * 模拟数据管理器
 * 
 * 职责：
 * 1. 计算模拟数据变化（自然衰减、灌溉效果）
 * 2. 将计算后的数据上报到服务端数据库
 * 
 * 注意：数据读取始终从服务端获取，不在本地缓存
 */
export class MockDataManager {
  private static instance: MockDataManager

  private baseData: EnvironmentData | null = null
  private lastUpdateTime: number = Date.now()
  private appConfig: AppConfig = AppConfig.getInstance()

  private config: MockConfig = {
    soilMoistureGainPerLiter: IrrigationCalibration.SOIL_MOISTURE_GAIN_PER_LITER,
    humidityGainPerLiter: IrrigationCalibration.HUMIDITY_GAIN_PER_LITER,
    maxSoilMoistureGain: IrrigationCalibration.MAX_SOIL_MOISTURE_GAIN,
    maxHumidityGain: IrrigationCalibration.MAX_HUMIDITY_GAIN,
    lightLuxPerBrightnessPercent: 7.5,
    ambientLightDecayPerMinute: 40,
    ambientRandomRange: 120,
    lightMin: 0,
    lightMax: 120000,
    soilMoistureDecayPerMinute: 0.8,
    humidityDecayPerMinute: 0.5,
    soilMoistureMin: 20,
    soilMoistureMax: 85,
    humidityMin: 30,
    humidityMax: 95,
    temperatureMin: 10,
    temperatureMax: 45,
    co2Min: 350,
    co2Max: 5000
  }

  static getInstance(): MockDataManager {
    if (!MockDataManager.instance) {
      MockDataManager.instance = new MockDataManager()
    }
    return MockDataManager.instance
  }

  private constructor() {}
  /**
   * 设置基准数据（从服务端获取后设置）
   */
  setBaseData(data: EnvironmentData): void {
    this.baseData = this.copyEnvironmentData(data)
    this.lastUpdateTime = Date.now()
  }

  /**
   * 应用灌溉效果并上报到数据库
   */
  async applyIrrigationEffect(durationSeconds: number, pointId: number = 1): Promise<EnvironmentData | null> {
    if (!this.appConfig.simulationMode || !this.baseData) {
      return null
    }

    const waterAmount = durationSeconds * IrrigationCalibration.FLOW_RATE_L_PER_SEC

    const soilMoistureGain = Math.min(
      waterAmount * this.config.soilMoistureGainPerLiter,
      this.config.maxSoilMoistureGain
    )

    const humidityGain = Math.min(
      waterAmount * this.config.humidityGainPerLiter,
      this.config.maxHumidityGain
    )

    // 计算衰减
    const decayResult = this.calculateDecay()

    // 计算新值
    const newSoilMoisture = this.clamp(
      this.baseData.soilMoisture - decayResult.soilMoistureDecay + soilMoistureGain,
      this.config.soilMoistureMin,
      this.config.soilMoistureMax
    )

    const newHumidity = this.clamp(
      this.baseData.humidity - decayResult.humidityDecay + humidityGain,
      this.config.humidityMin,
      this.config.humidityMax
    )

    const newTemperature = Math.max(15, this.baseData.temperature - Math.random() * 2)

    const newData: EnvironmentData = {
      pointId: pointId,
      temperature: newTemperature,
      humidity: newHumidity,
      light: this.baseData.light,
      co2: this.baseData.co2,
      soilMoisture: newSoilMoisture,
      timestamp: new Date().toISOString()
    }

    try {
      await this.uploadToServer(newData)
      console.log(`[MockDataManager] 灌溉效果已上报: 土壤湿度+${soilMoistureGain.toFixed(1)}%`)
      this.baseData = this.copyEnvironmentData(newData)
      this.lastUpdateTime = Date.now()
      return newData
    } catch (error) {
      console.error('[MockDataManager] 上报数据失败:', error)
      return null
    }
  }
  /**
   * 计算自然衰减
   */
  private calculateDecay(): DecayResult {
    const now = Date.now()
    const elapsedMinutes = (now - this.lastUpdateTime) / 60000

    return {
      soilMoistureDecay: elapsedMinutes * this.config.soilMoistureDecayPerMinute,
      humidityDecay: elapsedMinutes * this.config.humidityDecayPerMinute
    }
  }

  /**
   * 应用 LED 亮度控制后的光照变化并写入数据库
   */
  async applyLightControlEffect(
    brightness: number,
    targetLight: number = 300,
    pointId: number = 1
  ): Promise<EnvironmentData | null> {
    if (!this.appConfig.simulationMode || !this.baseData) {
      return null
    }

    const normalizedBrightness = this.clamp(Math.round(brightness), 0, 100)
    const decayResult = this.calculateDecay()
    const randomAmbientOffset = (Math.random() - 0.5) * 2 * this.config.ambientRandomRange
    const ambientLight = this.clamp(
      this.baseData.light - decayResult.humidityDecay * this.config.ambientLightDecayPerMinute + randomAmbientOffset,
      this.config.lightMin,
      this.config.lightMax
    )
    const ledContribution = normalizedBrightness * this.config.lightLuxPerBrightnessPercent

    let next = new EnvironmentData()
    next.pointId = pointId
    next.temperature = this.clamp(this.baseData.temperature + normalizedBrightness * 0.01, 10, 45)
    next.humidity = this.clamp(this.baseData.humidity - normalizedBrightness * 0.02, this.config.humidityMin, this.config.humidityMax)
    next.soilMoisture = this.clamp(
      this.baseData.soilMoisture - decayResult.soilMoistureDecay * 0.1,
      this.config.soilMoistureMin,
      this.config.soilMoistureMax
    )
    next.co2 = this.baseData.co2
    next.light = this.clamp(ambientLight + ledContribution, this.config.lightMin, this.config.lightMax)
    next.timestamp = new Date().toISOString()

    // 调光结果尽量向目标光照收敛，避免模拟波动过大
    if (targetLight > 0) {
      const correctedLight = next.light + (targetLight - next.light) * 0.35
      next.light = this.clamp(correctedLight, this.config.lightMin, this.config.lightMax)
    }

    try {
      await this.uploadToServer(next)
      this.baseData = this.copyEnvironmentData(next)
      this.lastUpdateTime = Date.now()
      return next
    } catch (error) {
      console.error('[MockDataManager] 上传光照模拟数据失败:', error)
      return null
    }
  }

  /**
   * 应用通风控制后的环境变化并写入数据库
   */
  async applyVentilationEffect(
    fanLevel: number,
    targetTemperature: number = 30,
    targetCo2: number = 1000,
    pointId: number = 1
  ): Promise<EnvironmentData | null> {
    if (!this.appConfig.simulationMode || !this.baseData) {
      return null
    }

    const level = this.clamp(Math.round(fanLevel), 0, 100)
    const decayResult = this.calculateDecay()

    const tempDrop = level * 0.03 + Math.random() * 0.25
    const humidityDrop = level * 0.04
    const co2Drop = level * 2.5 + Math.random() * 15
    const soilMoistureDrop = level * 0.01

    const next = new EnvironmentData()
    next.pointId = pointId
    next.temperature = this.clamp(
      this.baseData.temperature - tempDrop,
      this.config.temperatureMin,
      this.config.temperatureMax
    )
    next.humidity = this.clamp(
      this.baseData.humidity - decayResult.humidityDecay - humidityDrop,
      this.config.humidityMin,
      this.config.humidityMax
    )
    next.co2 = this.clamp(
      this.baseData.co2 - co2Drop,
      this.config.co2Min,
      this.config.co2Max
    )
    next.soilMoisture = this.clamp(
      this.baseData.soilMoisture - decayResult.soilMoistureDecay * 0.2 - soilMoistureDrop,
      this.config.soilMoistureMin,
      this.config.soilMoistureMax
    )
    next.light = this.baseData.light
    next.timestamp = new Date().toISOString()

    if (targetTemperature > 0) {
      next.temperature = this.clamp(
        next.temperature + (targetTemperature - next.temperature) * 0.25,
        this.config.temperatureMin,
        this.config.temperatureMax
      )
    }
    if (targetCo2 > 0) {
      next.co2 = this.clamp(
        next.co2 + (targetCo2 - next.co2) * 0.2,
        this.config.co2Min,
        this.config.co2Max
      )
    }

    try {
      await this.uploadToServer(next)
      this.baseData = this.copyEnvironmentData(next)
      this.lastUpdateTime = Date.now()
      return next
    } catch (error) {
      console.error('[MockDataManager] 上传通风模拟数据失败:', error)
      return null
    }
  }

  /**
   * 上报数据到服务端
   */
  private async uploadToServer(data: EnvironmentData): Promise<void> {
    const result = await HttpClient.post<ApiResponse<EnvironmentData>>('/api/environment', data)
    if (result.code !== 200) {
      throw new Error(result.message || '上报失败')
    }
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value))
  }
  getBaseData(): EnvironmentData | null {
    return this.baseData ? this.copyEnvironmentData(this.baseData) : null
  }
  reset(): void {
    this.baseData = null
    this.lastUpdateTime = Date.now()
  }

  /**
   * 复制EnvironmentData对象（替代展开运算符）
   */
  private copyEnvironmentData(data: EnvironmentData): EnvironmentData {
    const copy = new EnvironmentData()
    copy.id = data.id
    copy.pointId = data.pointId
    copy.temperature = data.temperature
    copy.humidity = data.humidity
    copy.light = data.light
    copy.co2 = data.co2
    copy.soilMoisture = data.soilMoisture
    copy.recordedAt = data.recordedAt
    copy.timestamp = data.timestamp
    copy.createdAt = data.createdAt
    copy.isConnected = data.isConnected
    return copy
  }
}
