import { AlarmRecord, AlarmType, AlarmConfig } from '../models/Alarm'
import { EnvironmentThreshold } from '../models/EnvironmentData'
import { HttpClient } from '../web/HttpClient'
import { PreferencesService } from './PreferencesService'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

interface AlarmDTO {
  id: number
  pointId: number
  alarmType: string
  alarmValue: number
  threshold: number
  status: number
  createdAt: string
  handledAt: string
}

interface HandleAlarmParams {
  remark?: string
}

interface HandleAllAlarmsParams {
}

export class AlarmService {
  private static instance: AlarmService

  // Local config cache only; no client-side alarm decisions.
  private threshold: EnvironmentThreshold = new EnvironmentThreshold()
  private config: AlarmConfig = new AlarmConfig()
  private prefsService: PreferencesService = PreferencesService.getInstance()
  private initialized: boolean = false

  static getInstance(): AlarmService {
    if (!AlarmService.instance) {
      AlarmService.instance = new AlarmService()
    }
    return AlarmService.instance
  }

  private constructor() {
  }

  /**
   * Load local config for UI settings. Backend owns alarm decisions.
   */
  async loadConfigFromStorage(): Promise<void> {
    if (this.initialized) return
    try {
      const savedThreshold = await this.prefsService.getEnvironmentThreshold()
      const savedConfig = await this.prefsService.getAlarmConfig()
      this.threshold = savedThreshold
      this.config = savedConfig
      this.initialized = true
    } catch (error) {
      console.error('[AlarmService] load config failed:', error)
    }
  }

  getConfig(): AlarmConfig {
    return this.config
  }

  async updateConfig(config: AlarmConfig): Promise<void> {
    this.config = config
    try {
      await this.prefsService.setAlarmConfig(config)
    } catch (error) {
      console.warn('[AlarmService] save config failed:', error)
    }
  }

  getThreshold(): EnvironmentThreshold {
    return this.threshold
  }

  async updateThreshold(threshold: EnvironmentThreshold): Promise<void> {
    this.threshold = threshold
    try {
      await this.prefsService.setEnvironmentThreshold(threshold)
    } catch (error) {
      console.warn('[AlarmService] save threshold failed:', error)
    }
  }

  async getAlarmList(pointId?: number, status?: number): Promise<AlarmRecord[]> {
    try {
      let url = '/api/alarm/list'
      let params: string[] = []
      if (pointId !== undefined) params.push(`pointId=${pointId}`)
      if (status !== undefined) params.push(`status=${status}`)
      if (params.length > 0) url += '?' + params.join('&')

      let result = await HttpClient.get<ApiResponse<AlarmDTO[]>>(url)
      return result.data.map(item => this.toRecord(item))
    } catch (error) {
      console.error('[AlarmService] get alarm list failed:', error)
      return []
    }
  }

  async getUnprocessedAlarms(): Promise<AlarmRecord[]> {
    return await this.getAlarmList(undefined, 0)
  }

  async getUnprocessedCount(): Promise<number> {
    try {
      let result = await HttpClient.get<ApiResponse<number>>('/api/alarm/unprocessed/count')
      return result.data
    } catch (error) {
      console.error('[AlarmService] get unprocessed count failed:', error)
      return 0
    }
  }

  async handleAlarm(id: string | number, remark?: string): Promise<boolean> {
    const alarmId = String(id)
    const numericId = Number(alarmId)

    if (!Number.isNaN(numericId)) {
      try {
        let params: HandleAlarmParams = { remark }
        let result = await HttpClient.put<ApiResponse<AlarmDTO>>(`/api/alarm/${numericId}/handle`, params)
        return result.code === 200
      } catch (error) {
        console.error('[AlarmService] handle alarm failed:', error)
        return false
      }
    }

    return false
  }

  async handleAllByPointId(pointId: number): Promise<boolean> {
    try {
      let params: HandleAllAlarmsParams = {}
      let result = await HttpClient.put<ApiResponse<void>>(`/api/alarm/handle-all?pointId=${pointId}`, params)
      return result.code === 200
    } catch (error) {
      console.error('[AlarmService] handle all failed:', error)
      return false
    }
  }

  private toRecord(dto: AlarmDTO): AlarmRecord {
    let record: AlarmRecord = new AlarmRecord()
    record.id = String(dto.id)
    record.alarmType = this.parseAlarmType(dto.alarmType)
    record.alarmValue = dto.alarmValue
    record.threshold = dto.threshold
    record.time = dto.createdAt
    record.isRead = dto.status === 1
    return record
  }

  private parseAlarmType(type: string): AlarmType {
    switch (type) {
      case 'TEMPERATURE_HIGH':
        return AlarmType.TEMPERATURE_HIGH
      case 'TEMPERATURE_LOW':
        return AlarmType.TEMPERATURE_LOW
      case 'HUMIDITY_HIGH':
        return AlarmType.HUMIDITY_HIGH
      case 'HUMIDITY_LOW':
        return AlarmType.HUMIDITY_LOW
      case 'LIGHT_LOW':
        return AlarmType.LIGHT_LOW
      case 'CO2_HIGH':
        return AlarmType.CO2_HIGH
      case 'SOIL_MOISTURE_LOW':
        return AlarmType.SOIL_MOISTURE_LOW
      case 'DEVICE_OFFLINE':
        return AlarmType.DEVICE_OFFLINE
      default:
        return AlarmType.TEMPERATURE_HIGH
    }
  }
}
