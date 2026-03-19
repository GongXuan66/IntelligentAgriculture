import { DeviceService } from './DeviceService'
import { SensorService } from './SensorService'
import { AppConfig } from '../config/AppConfig'
import { DeviceType } from '../models/Device'
import { GatewayEnvironmentControlPort, LightAdjustCommand } from '../mock/EnvironmentControlPort'

export interface LightControlResult {
  currentLight: number
  targetLight: number
  previousBrightness: number
  nextBrightness: number
  deltaLux: number
  adjusted: boolean
  success: boolean
  message: string
}

/**
 * 光照管理服务 - 支持多LED设备控制
 */
export class LightService {
  private static instance: LightService

  private readonly deviceService: DeviceService = new DeviceService()
  private readonly sensorService: SensorService = new SensorService()
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private readonly controlPort: GatewayEnvironmentControlPort = new GatewayEnvironmentControlPort()

  private readonly minBrightness: number = 0
  private readonly maxBrightness: number = 100
  private readonly deadBandLux: number = 20
  private readonly maxStepPerAdjust: number = 15

  private lightThreshold: number = 300
  // 支持多设备亮度状态
  private brightnessMap: Map<string, number> = new Map()

  private constructor() {}

  static getInstance(): LightService {
    if (!LightService.instance) {
      LightService.instance = new LightService()
    }
    return LightService.instance
  }

  private clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value))
  }

  getLightThreshold(): number {
    return this.lightThreshold
  }

  setLightThreshold(threshold: number): void {
    this.lightThreshold = Math.max(100, Math.min(2000, Math.round(threshold)))
  }

  getCurrentBrightness(deviceId?: string): number {
    if (deviceId) {
      return this.brightnessMap.get(deviceId) || 0
    }
    // 返回所有设备的平均亮度
    const values = Array.from(this.brightnessMap.values())
    if (values.length === 0) return 0
    return Math.round(values.reduce((a, b) => a + b, 0) / values.length)
  }

  async collectCurrentLight(pointId: number = 1): Promise<number> {
    let envData = await this.sensorService.getEnvironmentData(pointId)
    return envData.light
  }

  /**
   * 调整指定LED设备的亮度
   */
  async adjustBrightnessByTarget(
    targetLight: number = this.lightThreshold,
    pointId: number = 1,
    deviceIds?: string[]
  ): Promise<LightControlResult> {
    let currentLight = await this.collectCurrentLight(pointId)
    
    // 获取或使用传入的设备ID列表
    const targetDeviceIds = deviceIds || (await this.getLedDeviceIds())
    
    if (targetDeviceIds.length === 0) {
      return {
        currentLight: currentLight,
        targetLight: targetLight,
        previousBrightness: 0,
        nextBrightness: 0,
        deltaLux: 0,
        adjusted: false,
        success: false,
        message: '未找到LED设备'
      }
    }

    const firstDeviceId = targetDeviceIds[0]
    let previousBrightness = this.brightnessMap.get(firstDeviceId) || 0
    let deltaLux = targetLight - currentLight
    let nextBrightness = previousBrightness

    if (currentLight < 0) {
      return {
        currentLight: currentLight,
        targetLight: targetLight,
        previousBrightness: previousBrightness,
        nextBrightness: previousBrightness,
        deltaLux: deltaLux,
        adjusted: false,
        success: false,
        message: '光线采样失败'
      }
    }

    if (Math.abs(deltaLux) <= this.deadBandLux) {
      return {
        currentLight: currentLight,
        targetLight: targetLight,
        previousBrightness: previousBrightness,
        nextBrightness: previousBrightness,
        deltaLux: deltaLux,
        adjusted: false,
        success: true,
        message: '光在可控死区内'
      }
    }

    let rawStep = Math.round(deltaLux * 0.08)
    if (rawStep === 0) {
      rawStep = deltaLux > 0 ? 1 : -1
    }

    let step = this.clamp(rawStep, -this.maxStepPerAdjust, this.maxStepPerAdjust)
    nextBrightness = this.clamp(previousBrightness + step, this.minBrightness, this.maxBrightness)

    if (deltaLux > 0 && nextBrightness > 0 && nextBrightness < 10) {
      nextBrightness = 10
    }

    let success = await this.setLedBrightnessForDevices(nextBrightness, targetDeviceIds, targetLight, pointId)
    if (!success) {
      return {
        currentLight: currentLight,
        targetLight: targetLight,
        previousBrightness: previousBrightness,
        nextBrightness: previousBrightness,
        deltaLux: deltaLux,
        adjusted: false,
        success: false,
        message: 'LED亮度命令失败'
      }
    }

    this.lightThreshold = targetLight
    return {
      currentLight: currentLight,
      targetLight: targetLight,
      previousBrightness: previousBrightness,
      nextBrightness: nextBrightness,
      deltaLux: deltaLux,
      adjusted: nextBrightness !== previousBrightness,
      success: true,
      message: `${targetDeviceIds.length}个LED 调整至 ${nextBrightness}%`
    }
  }

  /**
   * 设置指定LED设备的亮度
   */
  async setLedBrightness(brightness: number, deviceIds?: string[]): Promise<boolean> {
    let normalized = this.clamp(Math.round(brightness), this.minBrightness, this.maxBrightness)
    
    // 获取或使用传入的设备ID列表
    const targetDeviceIds = deviceIds || (await this.getLedDeviceIds())
    
    if (targetDeviceIds.length === 0) {
      return false
    }
    
    return this.setLedBrightnessForDevices(normalized, targetDeviceIds, this.lightThreshold, 1)
  }

  /**
   * 为多个设备设置亮度
   */
  private async setLedBrightnessForDevices(
    brightness: number,
    deviceIds: string[],
    targetLight: number,
    pointId: number
  ): Promise<boolean> {
    let allSuccess = true
    
    for (const deviceId of deviceIds) {
      const success = await this.deviceService.controlDevice(deviceId, `brightness:${brightness}`)
      if (success) {
        this.brightnessMap.set(deviceId, brightness)
      } else {
        allSuccess = false
      }
    }

    if (allSuccess && this.appConfig.simulationMode) {
      let command = new LightAdjustCommand()
      command.pointId = pointId
      command.brightness = brightness
      command.targetLight = targetLight
      await this.controlPort.onLightAdjusted(command)
    }
    
    return allSuccess
  }

  /**
   * 获取所有LED设备ID
   */
  private async getLedDeviceIds(): Promise<string[]> {
    try {
      const devices = await this.deviceService.getDeviceList()
      return devices
        .filter(d => d.deviceType === DeviceType.LED)
        .map(d => d.deviceId)
    } catch (error) {
      console.error('[LightService] 获取LED设备列表失败:', error)
      return ['led_001'] // 默认返回第一个
    }
  }

  async autoLightControl(pointId: number = 1, deviceIds?: string[]): Promise<number> {
    let result = await this.adjustBrightnessByTarget(this.lightThreshold, pointId, deviceIds)
    return result.nextBrightness
  }

  async turnOnLed(deviceIds?: string[]): Promise<boolean> {
    return await this.setLedBrightness(this.maxBrightness, deviceIds)
  }

  async turnOffLed(deviceIds?: string[]): Promise<boolean> {
    return await this.setLedBrightness(this.minBrightness, deviceIds)
  }
}