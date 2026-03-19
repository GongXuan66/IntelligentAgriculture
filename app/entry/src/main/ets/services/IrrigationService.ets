import { IrrigationRecord, IrrigationConfig, IrrigationMode } from '../models/Irrigation'
import { HttpClient } from '../web/HttpClient'
import { AppConfig } from '../config/AppConfig'
import { EnvironmentData } from '../models/EnvironmentData'
import { IrrigationCalibration } from '../config/IrrigationCalibration'
import { GatewayEnvironmentControlPort, IrrigationCommand } from '../mock/EnvironmentControlPort'
import { PreferencesService } from './PreferencesService'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

interface IrrigationDTO {
  id: number
  pointId: number
  waterAmount: number
  duration: number
  mode: number
  startTime: string
  endTime: string
  createdAt: string
}

interface StartIrrigationParams {
  pointId: number
  duration: number
  mode: number
}

interface StopIrrigationParams {
  logId: number
}

interface IrrigationPlanConfigDTO {
  autoMode: boolean
  moistureThreshold: number
  minInterval: number
}

interface IrrigationPlanRequest {
  pointId: number
  envData: EnvironmentData
  config: IrrigationPlanConfigDTO
}

interface AutoIrrigationRequest {
  pointId: number
  envData: EnvironmentData
  config: IrrigationPlanConfigDTO
}

export interface AutoIrrigationPlan {
  shouldIrrigate: boolean
  waterAmountL: number
  durationSeconds: number
  targetMoisture: number
  moistureGap: number
  riskFactor: number
  reason: string
}

interface AutoIrrigationResult {
  started: boolean
  plan: AutoIrrigationPlan
  log: IrrigationDTO | null
}

class IrrigationState {
  isIrrigating: boolean = false
  currentLogId: number = 0
  duration: number = 0
  startTime: number = 0
  remainingTime: number = 0
  pointId: number = 1
  mode: number = 1
}

export class IrrigationService {
  // Legacy local planner constants kept for fallback compatibility.
  private static readonly MIN_AUTO_DURATION_SEC: number = 10
  private static readonly MAX_AUTO_DURATION_SEC: number = 180
  private static lastAutoIrrigationAt: number = 0

  private config: IrrigationConfig = new IrrigationConfig()
  private appConfig: AppConfig = AppConfig.getInstance()
  private prefsService: PreferencesService = PreferencesService.getInstance()
  private initialized: boolean = false

  private static state: IrrigationState = new IrrigationState()
  private static irrigationTimer: number = -1
  private static onCompleteCallback: (() => void) | null = null

  /**
   * 从本地存储加载配置（首次调用时自动加载）
   */
  async loadConfigFromStorage(): Promise<void> {
    if (this.initialized) return
    
    try {
      const savedConfig = await this.prefsService.getIrrigationConfig()
      this.config = savedConfig
      this.initialized = true
      console.log('[IrrigationService] 配置已从本地存储加载')
    } catch (error) {
      console.error('[IrrigationService] 加载配置失败:', error)
    }
  }

  getConfig(): IrrigationConfig {
    return this.config
  }

  async updateConfig(config: IrrigationConfig): Promise<void> {
    this.config = config
    try {
      await this.prefsService.setIrrigationConfig(config)
      console.log('[IrrigationService] 灌溉配置已保存到本地')
    } catch (error) {
      console.warn('[IrrigationService] 保存灌溉配置失败:', error)
    }
  }

  isSimulationMode(): boolean {
    return this.appConfig.simulationMode
  }

  static getIrrigationState(): IrrigationState {
    return {
      isIrrigating: IrrigationService.state.isIrrigating,
      currentLogId: IrrigationService.state.currentLogId,
      duration: IrrigationService.state.duration,
      startTime: IrrigationService.state.startTime,
      remainingTime: IrrigationService.state.remainingTime,
      pointId: IrrigationService.state.pointId,
      mode: IrrigationService.state.mode
    }
  }

  static isCurrentlyIrrigating(): boolean {
    return IrrigationService.state.isIrrigating
  }

  static getRemainingTime(): number {
    if (!IrrigationService.state.isIrrigating) {
      return 0
    }
    const elapsed = Math.floor((Date.now() - IrrigationService.state.startTime) / 1000)
    return Math.max(0, IrrigationService.state.duration - elapsed)
  }

  setOnIrrigationComplete(callback: () => void): void {
    IrrigationService.onCompleteCallback = callback
  }

  async startIrrigation(pointId: number = 1, duration: number, mode: number = 1): Promise<IrrigationDTO> {
    IrrigationService.state.isIrrigating = true
    IrrigationService.state.duration = duration
    IrrigationService.state.startTime = Date.now()
    IrrigationService.state.remainingTime = duration
    IrrigationService.state.pointId = pointId
    IrrigationService.state.mode = mode

    IrrigationService.startCountdown()

    try {
      let params: StartIrrigationParams = { pointId, duration, mode }
      let result = await HttpClient.post<ApiResponse<IrrigationDTO>>('/api/irrigation/start', params)
      IrrigationService.state.currentLogId = result.data.id
      return result.data
    } catch (error) {
      console.error('[IrrigationService] 启动灌溉失败:', error)

      return {
        id: Date.now(),
        pointId: pointId,
        waterAmount: 0,
        duration: duration,
        mode: mode,
        startTime: new Date().toISOString(),
        endTime: '',
        createdAt: new Date().toISOString()
      }
    }
  }

  private static startCountdown(): void {
    if (IrrigationService.irrigationTimer !== -1) {
      clearInterval(IrrigationService.irrigationTimer)
    }

    IrrigationService.irrigationTimer = setInterval(() => {
      const remaining = IrrigationService.getRemainingTime()
      IrrigationService.state.remainingTime = remaining
      if (remaining <= 0) {
        IrrigationService.completeIrrigation()
      }
    }, 1000)
  }

  private static async completeIrrigation(): Promise<void> {
    if (IrrigationService.irrigationTimer !== -1) {
      clearInterval(IrrigationService.irrigationTimer)
      IrrigationService.irrigationTimer = -1
    }

    const logId = IrrigationService.state.currentLogId
    const duration = IrrigationService.state.duration

    try {
      await IrrigationService.stopIrrigationInternal(logId, duration)
    } catch (error) {
      console.error('[IrrigationService] 完成灌溉任务失败:', error)

    } finally {
      IrrigationService.state.isIrrigating = false
      IrrigationService.state.remainingTime = 0
      if (IrrigationService.onCompleteCallback) {
        IrrigationService.onCompleteCallback()
      }
    }
  }

  async stopIrrigation(logId: number): Promise<IrrigationDTO> {
    return IrrigationService.stopIrrigationInternal(logId, IrrigationService.state.duration)
  }

  private static async stopIrrigationInternal(logId: number, duration: number): Promise<IrrigationDTO> {
    const appConfig = AppConfig.getInstance()
    const controlPort = new GatewayEnvironmentControlPort()

    let command = new IrrigationCommand()
    command.pointId = IrrigationService.state.pointId
    command.durationSeconds = duration
    command.mode = IrrigationService.state.mode

    try {
      let params: StopIrrigationParams = { logId }
      let result = await HttpClient.post<ApiResponse<IrrigationDTO>>('/api/irrigation/stop', params)

      if (appConfig.simulationMode) {
        await controlPort.onIrrigationCompleted(command)
      }

      if (IrrigationService.irrigationTimer !== -1) {
        clearInterval(IrrigationService.irrigationTimer)
        IrrigationService.irrigationTimer = -1
      }

      IrrigationService.state.isIrrigating = false
      IrrigationService.state.remainingTime = 0
      return result.data
    } catch (error) {
      console.error('[IrrigationService] stop irrigation failed:', error)

      if (appConfig.simulationMode) {
        await controlPort.onIrrigationCompleted(command)
      }

      IrrigationService.state.isIrrigating = false

      return {
        id: logId,
        pointId: IrrigationService.state.pointId,
        waterAmount: duration * IrrigationCalibration.FLOW_RATE_L_PER_SEC,
        duration: duration,
        mode: IrrigationService.state.mode,
        startTime: new Date(Date.now() - duration * 1000).toISOString(),
        endTime: new Date().toISOString(),
        createdAt: new Date().toISOString()
      }
    }
  }

  async simulateIrrigation(duration: number, pointId: number = 1, mode: number = 1): Promise<IrrigationDTO> {
    return this.startIrrigation(pointId, duration, mode)
  }

  // Build config payload for backend planning.
  private buildPlanConfig(): IrrigationPlanConfigDTO {
    return {
      autoMode: this.config.autoMode,
      moistureThreshold: this.config.moistureThreshold,
      minInterval: this.config.minInterval
    }
  }

  // Request a backend-computed auto irrigation plan.
  async fetchAutoPlan(envData: EnvironmentData, pointId: number = 1): Promise<AutoIrrigationPlan> {
    const payload: IrrigationPlanRequest = {
      pointId,
      envData,
      config: this.buildPlanConfig()
    }

    const result = await HttpClient.post<ApiResponse<AutoIrrigationPlan>>('/api/irrigation/plan', payload)
    return result.data
  }

  // Compute plan and start auto irrigation on backend.
  async startAutoIrrigationByEnvironmentRemote(
    envData: EnvironmentData,
    pointId: number = 1
  ): Promise<AutoIrrigationResult> {
    const payload: AutoIrrigationRequest = {
      pointId,
      envData,
      config: this.buildPlanConfig()
    }

    const result = await HttpClient.post<ApiResponse<AutoIrrigationResult>>('/api/irrigation/auto/start', payload)
    if (result.data.started && result.data.log) {
      IrrigationService.state.isIrrigating = true
      IrrigationService.state.duration = result.data.plan.durationSeconds
      IrrigationService.state.startTime = Date.now()
      IrrigationService.state.remainingTime = result.data.plan.durationSeconds
      IrrigationService.state.pointId = pointId
      IrrigationService.state.mode = 0
      IrrigationService.state.currentLogId = result.data.log.id
      IrrigationService.startCountdown()
    }
    return result.data
  }

  // Deprecated local planner kept for fallback and tests.
  calculateAutoIrrigationPlan(
    envData: EnvironmentData,
    config: IrrigationConfig = this.config
  ): AutoIrrigationPlan {
    const threshold = this.clamp(config.moistureThreshold, 20, 70)

    if (envData.soilMoisture < 0) {
      // 当土壤湿度数据不可用时，返回不进行灌溉的计划
      return this.buildNoIrrigationPlan(threshold, '土壤湿度数据不可用')

    }

    const soilMoisture = this.clamp(envData.soilMoisture, 0, 100)
    if (soilMoisture >= threshold) {
      return this.buildNoIrrigationPlan(threshold, '土壤湿度高于阈值')
    }

    const targetMoisture = Math.min(75, threshold + 12)
    const moistureGap = this.clamp(targetMoisture - soilMoisture, 0, 60)
    const baseWaterAmount = moistureGap / IrrigationCalibration.SOIL_MOISTURE_GAIN_PER_LITER

    let riskFactor = 1
    if (envData.temperature > 35) {
      riskFactor += 0.2
    } else if (envData.temperature > 30) {
      riskFactor += 0.1
    } else if (envData.temperature < 15) {
      riskFactor -= 0.08
    }

    if (envData.humidity > 0 && envData.humidity < 40) {
      riskFactor += 0.1
    } else if (envData.humidity > 75) {
      riskFactor -= 0.08
    }

    if (envData.light > 30000) {
      riskFactor += 0.15
    } else if (envData.light > 15000) {
      riskFactor += 0.08
    } else if (envData.light > 0 && envData.light < 1000) {
      riskFactor -= 0.05
    }

    if (envData.co2 > 1000) {
      riskFactor += 0.05
    }

    riskFactor = this.clamp(riskFactor, 0.75, 1.45)
    const waterAmountL = this.clamp(baseWaterAmount * riskFactor, 0.5, 45)
    const rawDuration = Math.round(waterAmountL / IrrigationCalibration.FLOW_RATE_L_PER_SEC)
    const durationSeconds = this.clamp(rawDuration, IrrigationService.MIN_AUTO_DURATION_SEC, IrrigationService.MAX_AUTO_DURATION_SEC)

    return {
      shouldIrrigate: true,
      waterAmountL: Number(waterAmountL.toFixed(1)),
      durationSeconds,
      targetMoisture: Number(targetMoisture.toFixed(1)),
      moistureGap: Number(moistureGap.toFixed(1)),
      riskFactor: Number(riskFactor.toFixed(2)),
      reason: '土壤湿度低于阈值，自动生成灌溉计划'

    }
  }

  async startAutoIrrigationByEnvironment(
    envData: EnvironmentData,
    pointId: number = 1
  ): Promise<AutoIrrigationResult> {
    const plan = this.calculateAutoIrrigationPlan(envData)

    if (!this.config.autoMode) {
      const modifiedPlan: AutoIrrigationPlan = {
        shouldIrrigate: false,
        waterAmountL: plan.waterAmountL,
        durationSeconds: plan.durationSeconds,
        targetMoisture: plan.targetMoisture,
        moistureGap: plan.moistureGap,
        riskFactor: plan.riskFactor,
        reason: '自动灌溉模式已禁用'
      }
      return {
        started: false,
        log: null,
        plan: modifiedPlan
      }
    }

    if (!plan.shouldIrrigate) {
      return {
        started: false,
        log: null,
        plan: plan
      }
    }

    if (IrrigationService.isCurrentlyIrrigating()) {
      const modifiedPlan: AutoIrrigationPlan = {
        shouldIrrigate: false,
        waterAmountL: plan.waterAmountL,
        durationSeconds: plan.durationSeconds,
        targetMoisture: plan.targetMoisture,
        moistureGap: plan.moistureGap,
        riskFactor: plan.riskFactor,
        reason: '灌溉任务已经在运行'
      }
      return {
        started: false,
        log: null,
        plan: modifiedPlan
      }
    }

    const minIntervalMs = Math.max(60, this.config.minInterval) * 1000
    const elapsed = Date.now() - IrrigationService.lastAutoIrrigationAt
    if (IrrigationService.lastAutoIrrigationAt > 0 && elapsed < minIntervalMs) {
      const waitSec = Math.ceil((minIntervalMs - elapsed) / 1000)
      const modifiedPlan: AutoIrrigationPlan = {
        shouldIrrigate: false,
        waterAmountL: plan.waterAmountL,
        durationSeconds: plan.durationSeconds,
        targetMoisture: plan.targetMoisture,
        moistureGap: plan.moistureGap,
        riskFactor: plan.riskFactor,
        reason: `自动灌溉冷却，等待 ${waitSec} 秒`
      }
      return {
        started: false,
        log: null,
        plan: modifiedPlan
      }
    }

    const log = await this.startIrrigation(pointId, plan.durationSeconds, 0)
    IrrigationService.lastAutoIrrigationAt = Date.now()
    return {
      started: true,
      plan: plan,
      log: log
    }
  }

  async getIrrigationHistory(pointId: number = 1): Promise<IrrigationRecord[]> {
    try {
      let result = await HttpClient.get<ApiResponse<IrrigationDTO[]>>('/api/irrigation/logs?pointId=' + pointId)
      return result.data.map(this.toRecord)
    } catch (error) {
      console.error('获取灌溉历史失败：', error)
      return []
    }
  }

  async getLatestLog(pointId: number = 1): Promise<IrrigationRecord | null> {
    try {
      let result = await HttpClient.get<ApiResponse<IrrigationDTO>>('/api/irrigation/latest?pointId=' + pointId)
      return this.toRecord(result.data)
    } catch (error) {
      console.error('获取最新灌溉日志失败：', error)
      return null
    }
  }

  async getTotalWaterAmount(pointId: number = 1): Promise<number> {
    try {
      let result = await HttpClient.get<ApiResponse<number>>('/api/irrigation/total?pointId=' + pointId)
      return result.data
    } catch (error) {
      console.error('获取总灌溉用水失败：', error)
      return 0
    }
  }

  private toRecord(dto: IrrigationDTO): IrrigationRecord {
    return {
      id: String(dto.id),
      startTime: dto.startTime,
      endTime: dto.endTime || '',
      duration: dto.duration || 0,
      waterAmount: dto.waterAmount || 0,
      mode: dto.mode === 0 ? IrrigationMode.AUTO : IrrigationMode.MANUAL,
      soilMoistureBefore: 0,
      soilMoistureAfter: 0
    }
  }

  private buildNoIrrigationPlan(targetMoisture: number, reason: string): AutoIrrigationPlan {
    return {
      shouldIrrigate: false,
      waterAmountL: 0,
      durationSeconds: 0,
      targetMoisture: Number(targetMoisture.toFixed(1)),
      moistureGap: 0,
      riskFactor: 1,
      reason
    }
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value))
  }
}
