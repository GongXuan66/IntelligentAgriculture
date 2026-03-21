import { Device, DeviceStatus, DeviceType, DeviceCommand } from '../models/Device'
import { BooleanResponse, DeviceStatusResponse } from '../models/EnvironmentData'
import { HttpClient } from '../web/HttpClient'
import { PreferencesService, OfflineCommand } from './PreferencesService'

/**
 * API响应结构
 */
interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 设备DTO
 */
interface DeviceDTO {
  id: number
  pointId: number
  deviceId: string
  deviceName: string
  deviceType: string
  status: number
  createdAt: string
  updatedAt: string
}

/**
 * 设备管理服务
 */
export class DeviceService {
  private prefsService: PreferencesService = PreferencesService.getInstance()
  
  // 缓存有效期：5分钟
  private readonly CACHE_MAX_AGE = 5 * 60 * 1000

  /**
   * 获取设备列表（带缓存）
   */
  async getDeviceList(pointId?: number): Promise<Device[]> {
    let url = '/api/device/list'
    if (pointId) {
      url += `?pointId=${pointId}`
    }
    console.info(`[DeviceService] 请求设备列表: ${url}`)
    
    try {
      let result = await HttpClient.get<ApiResponse<DeviceDTO[]>>(url)
      console.info(`[DeviceService] API返回成功, 设备数量: ${result.data.length}`)
      const devices = result.data.map((dto: DeviceDTO) => this.toDevice(dto))
      
      // 保存到缓存
      try {
        await this.prefsService.setDeviceListCache(devices)
        await this.prefsService.setLastSyncTime(Date.now())
      } catch (cacheError) {
        console.warn('[DeviceService] 缓存保存失败:', cacheError)
      }
      
      return devices
    } catch (err) {
      let errorMsg = err instanceof Error ? err.message : String(err)
      console.error('[DeviceService] API请求失败:', errorMsg)
      
      // 返回空数组，让界面显示"暂无设备"
      return []
    }
  }
  
  /**
   * 获取缓存的设备列表（不请求网络）
   */
  async getCachedDeviceList(): Promise<Device[] | null> {
    try {
      const cached = await this.prefsService.getDeviceListCache()
      if (cached) {
        return cached.devices
      }
    } catch (error) {
      console.warn('[DeviceService] 获取缓存失败:', error)
    }
    return null
  }

  /**
   * 获取单个设备信息
   */
  async getDevice(id: number): Promise<Device> {
    try {
      let result = await HttpClient.get<ApiResponse<DeviceDTO>>(`/api/device/${id}`)
      return this.toDevice(result.data)
    } catch (error) {
      console.error('获取设备信息失败:', error)
      throw new Error('获取设备信息失败')
    }
  }

  /**
   * 控制设备（支持离线队列）
   */
  async controlDevice(deviceId: string, command: string): Promise<boolean> {
    try {
      let result = await HttpClient.post<ApiResponse<DeviceDTO>>(
        '/api/device/control',
        { deviceId: deviceId, command: command } as DeviceCommand
      )
      
      if (result.code === 200) {
        // 成功后尝试同步离线命令（忽略错误）
        try {
          await this.syncOfflineCommands()
        } catch (syncError) {
          console.warn('[DeviceService] 同步离线命令失败:', syncError)
        }
        return true
      }
      return false
    } catch (error) {
      console.error('控制设备失败，添加到离线队列:', error)
      
      // 添加到离线队列（忽略错误）
      try {
        await this.prefsService.addOfflineCommand(deviceId, command)
        console.log('[DeviceService] 命令已添加到离线队列')
      } catch (queueError) {
        console.warn('[DeviceService] 添加离线命令失败:', queueError)
      }
      return false
    }
  }
  
  /**
   * 同步离线命令
   */
  async syncOfflineCommands(): Promise<number> {
    let queue: OfflineCommand[] = []
    try {
      queue = await this.prefsService.getOfflineCommandQueue()
    } catch (error) {
      console.warn('[DeviceService] 获取离线队列失败:', error)
      return 0
    }
    
    const pending = queue.filter(cmd => !cmd.synced)
    
    if (pending.length === 0) {
      return 0
    }
    
    let syncedCount = 0
    for (const cmd of pending) {
      try {
        let result = await HttpClient.post<ApiResponse<DeviceDTO>>(
          '/api/device/control',
          { deviceId: cmd.deviceId, command: cmd.command } as DeviceCommand
        )
        
        if (result.code === 200) {
          try {
            await this.prefsService.markCommandSynced(cmd.id)
          } catch (e) {
            console.warn('[DeviceService] 标记命令同步失败:', e)
          }
          syncedCount++
          console.log(`[DeviceService] 离线命令已同步: ${cmd.id}`)
        }
      } catch (error) {
        console.error(`[DeviceService] 同步命令失败: ${cmd.id}`, error)
      }
    }
    
    // 清理已同步的命令（忽略错误）
    try {
      await this.prefsService.removeSyncedCommands()
    } catch (e) {
      console.warn('[DeviceService] 清理命令失败:', e)
    }
    return syncedCount
  }
  
  /**
   * 获取待同步命令数量
   */
  async getPendingCommandCount(): Promise<number> {
    try {
      return await this.prefsService.getPendingCommandCount()
    } catch (error) {
      console.warn('[DeviceService] 获取待同步命令数量失败:', error)
      return 0
    }
  }

  /**
   * 获取设备状态
   */
  async getDeviceStatus(deviceId: string): Promise<DeviceStatus> {
    try {
      let result = await HttpClient.get<ApiResponse<DeviceDTO>>(
        `/api/device/${deviceId}/status`
      )
      return this.parseStatus(result.data.status)
    } catch (error) {
      console.error('获取设备状态失败:', error)
      return DeviceStatus.OFFLINE
    }
  }

  /**
   * 开启设备
   */
  async turnOn(deviceId: string): Promise<boolean> {
    return await this.controlDevice(deviceId, 'on')
  }

  /**
   * 关闭设备
   */
  async turnOff(deviceId: string): Promise<boolean> {
    return await this.controlDevice(deviceId, 'off')
  }

  /**
   * 开启水泵
   */
  async turnOnWaterPump(): Promise<boolean> {
    return await this.controlDevice('pump_001', 'on')
  }

  /**
   * 关闭水泵
   */
  async turnOffWaterPump(): Promise<boolean> {
    return await this.controlDevice('pump_001', 'off')
  }

  /**
   * 设置LED亮度
   */
  async setLedBrightness(brightness: number): Promise<boolean> {
    let normalized = Math.max(0, Math.min(100, Math.round(brightness)))
    return await this.controlDevice('led_001', `brightness:${normalized}`)
  }

  /**
   * 开启风扇
   */
  async turnOnFan(): Promise<boolean> {
    return await this.controlDevice('fan_001', 'on')
  }

  /**
   * 关闭风扇
   */
  async turnOffFan(): Promise<boolean> {
    return await this.controlDevice('fan_001', 'off')
  }

  /**
   * 转换DTO到Device
   */
  private toDevice(dto: DeviceDTO): Device {
    return {
      deviceId: dto.deviceId,
      deviceName: dto.deviceName,
      deviceType: this.parseDeviceType(dto.deviceType),
      status: this.parseStatus(dto.status),
      lastUpdate: dto.updatedAt
    }
  }

  /**
   * 解析设备类型
   */
  private parseDeviceType(type: string): DeviceType {
    switch (type) {
      case 'pump':
        return DeviceType.WATER_PUMP
      case 'led':
        return DeviceType.LED
      case 'fan':
        return DeviceType.FAN
      case 'valve':
        return DeviceType.VALVE
      default:
        return DeviceType.WATER_PUMP
    }
  }

  /**
   * 解析设备状态
   */
  private parseStatus(status: number): DeviceStatus {
    switch (status) {
      case 0:
        return DeviceStatus.OFFLINE
      case 1:
        return DeviceStatus.ONLINE
      case 2:
        return DeviceStatus.WORKING
      default:
        return DeviceStatus.OFFLINE
    }
  }

  /**
   * 模拟设备数据（开发测试用）
   */
  private getMockDevices(): Device[] {
    return [
      {
        deviceId: 'pump_001',
        deviceName: '水泵1号',
        deviceType: DeviceType.WATER_PUMP,
        status: DeviceStatus.ONLINE,
        lastUpdate: new Date().toISOString()
      },
      {
        deviceId: 'led_001',
        deviceName: 'LED补光灯1号',
        deviceType: DeviceType.LED,
        status: DeviceStatus.ONLINE,
        lastUpdate: new Date().toISOString()
      },
      {
        deviceId: 'fan_001',
        deviceName: '通风风扇1号',
        deviceType: DeviceType.FAN,
        status: DeviceStatus.ONLINE,
        lastUpdate: new Date().toISOString()
      },
      {
        deviceId: 'valve_001',
        deviceName: '水阀1号',
        deviceType: DeviceType.VALVE,
        status: DeviceStatus.ONLINE,
        lastUpdate: new Date().toISOString()
      }
    ]
  }
}
