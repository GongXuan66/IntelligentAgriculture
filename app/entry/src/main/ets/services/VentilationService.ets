import { DeviceService } from './DeviceService'
import { SensorService } from './SensorService'
import { AppConfig } from '../config/AppConfig'
import { DeviceType } from '../models/Device'
import { GatewayEnvironmentControlPort, VentilationAdjustCommand } from '../mock/EnvironmentControlPort'

export interface VentilationControlResult {
  currentTemperature: number
  currentCo2: number
  targetTemperature: number
  targetCo2: number
  previousFanLevel: number
  nextFanLevel: number
  adjusted: boolean
  success: boolean
  message: string
}

/**
 * 通风管理服务 - 支持多风扇设备控制
 */
export class VentilationService {
  private static instance: VentilationService

  private readonly deviceService: DeviceService = new DeviceService()
  private readonly sensorService: SensorService = new SensorService()
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private readonly controlPort: GatewayEnvironmentControlPort = new GatewayEnvironmentControlPort()

  private readonly minFanLevel: number = 0
  private readonly maxFanLevel: number = 100
  private readonly minEffectiveFanLevel: number = 20
  private readonly deadBandTemperature: number = 0.5
  private readonly deadBandCo2: number = 40
  private readonly maxStepPerAdjust: number = 20

  private targetTemperature: number = 30
  private targetCo2: number = 1000
  // 支持多设备档位状态
  private fanLevelMap: Map<string, number> = new Map()

  private constructor() {}

  static getInstance(): VentilationService {
    if (!VentilationService.instance) {
      VentilationService.instance = new VentilationService()
    }
    return VentilationService.instance
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value))
  }

  getTargetTemperature(): number {
    return this.targetTemperature
  }

  setTargetTemperature(targetTemperature: number): void {
    this.targetTemperature = this.clamp(Math.round(targetTemperature), 18, 40)
  }

  getTargetCo2(): number {
    return this.targetCo2
  }

  setTargetCo2(targetCo2: number): void {
    this.targetCo2 = this.clamp(Math.round(targetCo2), 600, 2000)
  }

  getCurrentFanLevel(deviceId?: string): number {
    if (deviceId) {
      return this.fanLevelMap.get(deviceId) || 0
    }
    // 返回所有设备的平均档位
    const values = Array.from(this.fanLevelMap.values())
    if (values.length === 0) return 0
    return Math.round(values.reduce((a, b) => a + b, 0) / values.length)
  }

  async adjustFanByTarget(
    targetTemperature: number = this.targetTemperature,
    targetCo2: number = this.targetCo2,
    pointId: number = 1,
    deviceIds?: string[]
  ): Promise<VentilationControlResult> {
    let envData = await this.sensorService.getEnvironmentData(pointId)
    let currentTemperature = envData.temperature
    let currentCo2 = envData.co2

    // 获取或使用传入的设备ID列表
    const targetDeviceIds = deviceIds || (await this.getFanDeviceIds())

    if (targetDeviceIds.length === 0) {
      return {
        currentTemperature: currentTemperature,
        currentCo2: currentCo2,
        targetTemperature: targetTemperature,
        targetCo2: targetCo2,
        previousFanLevel: 0,
        nextFanLevel: 0,
        adjusted: false,
        success: false,
        message: '未找到风扇设备'
      }
    }

    const firstDeviceId = targetDeviceIds[0]
    let previousFanLevel = this.fanLevelMap.get(firstDeviceId) || 0

    if (currentTemperature < 0 || currentCo2 < 0) {
      return {
        currentTemperature: currentTemperature,
        currentCo2: currentCo2,
        targetTemperature: targetTemperature,
        targetCo2: targetCo2,
        previousFanLevel: previousFanLevel,
        nextFanLevel: previousFanLevel,
        adjusted: false,
        success: false,
        message: '通风采样失败'
      }
    }

    const tempGap = currentTemperature - targetTemperature
    const co2Gap = currentCo2 - targetCo2
    const needCooling = tempGap > this.deadBandTemperature
    const needVentCo2 = co2Gap > this.deadBandCo2

    if (!needCooling && !needVentCo2) {
      const nextFanLevel = this.clamp(previousFanLevel - 10, this.minFanLevel, this.maxFanLevel)
      if (nextFanLevel === previousFanLevel) {
        return {
          currentTemperature: currentTemperature,
          currentCo2: currentCo2,
          targetTemperature: targetTemperature,
          targetCo2: targetCo2,
          previousFanLevel: previousFanLevel,
          nextFanLevel: previousFanLevel,
          adjusted: false,
          success: true,
          message: '环境在目标区间内'
        }
      }

      const success = await this.setFanLevelForDevices(nextFanLevel, targetDeviceIds, targetTemperature, targetCo2, pointId)
      return {
        currentTemperature: currentTemperature,
        currentCo2: currentCo2,
        targetTemperature: targetTemperature,
        targetCo2: targetCo2,
        previousFanLevel: previousFanLevel,
        nextFanLevel: success ? nextFanLevel : previousFanLevel,
        adjusted: success,
        success: success,
        message: success ? `${targetDeviceIds.length}个风扇降速到 ${nextFanLevel}%` : '风扇调节失败'
      }
    }

    const tempDemand = needCooling ? this.clamp(Math.round((tempGap / 8) * 100), 0, 100) : 0
    const co2Demand = needVentCo2 ? this.clamp(Math.round((co2Gap / 1200) * 100), 0, 100) : 0
    const targetFanLevel = Math.max(tempDemand, co2Demand)

    let delta = targetFanLevel - previousFanLevel
    delta = this.clamp(delta, -this.maxStepPerAdjust, this.maxStepPerAdjust)
    let nextFanLevel = this.clamp(previousFanLevel + delta, this.minFanLevel, this.maxFanLevel)
    if (targetFanLevel > 0 && nextFanLevel > 0 && nextFanLevel < this.minEffectiveFanLevel) {
      nextFanLevel = this.minEffectiveFanLevel
    }

    const success = await this.setFanLevelForDevices(nextFanLevel, targetDeviceIds, targetTemperature, targetCo2, pointId)
    return {
      currentTemperature: currentTemperature,
      currentCo2: currentCo2,
      targetTemperature: targetTemperature,
      targetCo2: targetCo2,
      previousFanLevel: previousFanLevel,
      nextFanLevel: success ? nextFanLevel : previousFanLevel,
      adjusted: success && nextFanLevel !== previousFanLevel,
      success: success,
      message: success ? `${targetDeviceIds.length}个风扇调节到 ${nextFanLevel}%` : '风扇调节失败'
    }
  }

  async setFanLevel(fanLevel: number, deviceIds?: string[]): Promise<boolean> {
    let normalized = this.clamp(Math.round(fanLevel), this.minFanLevel, this.maxFanLevel)
    const targetDeviceIds = deviceIds || (await this.getFanDeviceIds())
    return this.setFanLevelForDevices(normalized, targetDeviceIds, this.targetTemperature, this.targetCo2, 1)
  }

  /**
   * 为多个设备设置档位
   */
  private async setFanLevelForDevices(
    fanLevel: number,
    deviceIds: string[],
    targetTemperature: number,
    targetCo2: number,
    pointId: number
  ): Promise<boolean> {
    const normalized = this.clamp(Math.round(fanLevel), this.minFanLevel, this.maxFanLevel)
    let allSuccess = true

    for (const deviceId of deviceIds) {
      const success = normalized <= 0
        ? await this.deviceService.controlDevice(deviceId, 'off')
        : await this.deviceService.controlDevice(deviceId, `level:${normalized}`)
      
      if (success) {
        this.fanLevelMap.set(deviceId, normalized)
      } else {
        allSuccess = false
      }
    }

    if (allSuccess) {
      this.targetTemperature = targetTemperature
      this.targetCo2 = targetCo2

      if (this.appConfig.simulationMode) {
        let command = new VentilationAdjustCommand()
        command.pointId = pointId
        command.fanLevel = normalized
        command.targetTemperature = targetTemperature
        command.targetCo2 = targetCo2
        await this.controlPort.onVentilationAdjusted(command)
      }
    }

    return allSuccess
  }

  /**
   * 获取所有风扇设备ID
   */
  private async getFanDeviceIds(): Promise<string[]> {
    try {
      const devices = await this.deviceService.getDeviceList()
      return devices
        .filter(d => d.deviceType === DeviceType.FAN)
        .map(d => d.deviceId)
    } catch (error) {
      console.error('[VentilationService] 获取风扇设备列表失败:', error)
      return ['fan_001']
    }
  }

  async turnOnFan(deviceIds?: string[]): Promise<boolean> {
    const targetDeviceIds = deviceIds || (await this.getFanDeviceIds())
    return this.setFanLevelForDevices(this.maxFanLevel, targetDeviceIds, this.targetTemperature, this.targetCo2, 1)
  }

  async turnOffFan(deviceIds?: string[]): Promise<boolean> {
    const targetDeviceIds = deviceIds || (await this.getFanDeviceIds())
    return this.setFanLevelForDevices(this.minFanLevel, targetDeviceIds, this.targetTemperature, this.targetCo2, 1)
  }
}