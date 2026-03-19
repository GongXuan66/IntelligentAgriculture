import {
  DashboardStats,
  BaseInfo,
  DeviceStats,
  ControlStats,
  TaskStats,
  AlarmStats,
  IrrigationStats,
  TraceStats
} from '../models/Stats'
import { HttpClient } from '../web/HttpClient'
import { DeviceService } from './DeviceService'
import { AlarmService } from './AlarmService'
import { IrrigationService } from './IrrigationService'
import { DeviceStatus, DeviceType } from '../models/Device'

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 统计数据服务
 */
export class StatsService {
  private static instance: StatsService
  private deviceService: DeviceService = new DeviceService()
  private alarmService: AlarmService = AlarmService.getInstance()
  private irrigationService: IrrigationService = new IrrigationService()

  static getInstance(): StatsService {
    if (!StatsService.instance) {
      StatsService.instance = new StatsService()
    }
    return StatsService.instance
  }

  /**
   * 获取仪表盘全部统计数据
   */
  async getDashboardStats(): Promise<DashboardStats> {
    const stats = new DashboardStats()
    
    // 并行请求各模块数据
    const results = await Promise.all([
      this.getDeviceStats(),
      this.getAlarmStats(),
      this.getIrrigationStats()
    ])
    
    stats.deviceStats = results[0]
    stats.alarmStats = results[1]
    stats.irrigationStats = results[2]
    
    // 尝试从后端获取基地信息
    try {
      const result = await HttpClient.get<ApiResponse<BaseInfo>>('/api/base/info')
      if (result.code === 200 && result.data) {
        stats.baseInfo = result.data
      }
    } catch (error) {
      console.warn('[StatsService] 获取基地信息失败，使用默认值')
    }
    
    return stats
  }

  /**
   * 获取设备统计
   */
  async getDeviceStats(): Promise<DeviceStats> {
    const stats = new DeviceStats()
    
    try {
      const devices = await this.deviceService.getDeviceList()
      stats.total = devices.length
      
      // 统计状态
      for (const device of devices) {
        switch (device.status) {
          case DeviceStatus.ONLINE:
            stats.online++
            break
          case DeviceStatus.OFFLINE:
            stats.offline++
            break
          case DeviceStatus.WORKING:
            stats.working++
            break
        }
        
        // 统计类型
        switch (device.deviceType) {
          case DeviceType.SENSOR:
            stats.sensors++
            break
          case DeviceType.FAN:
            stats.others++
            break
          case DeviceType.LED:
            stats.others++
            break
          case DeviceType.WATER_PUMP:
            stats.others++
            break
          case DeviceType.VALVE:
            stats.others++
            break
        }
      }
      
      // 确保在线数包含工作中设备
      stats.online = stats.online + stats.working
      
    } catch (error) {
      console.error('[StatsService] 获取设备统计失败:', error)
      // 使用模拟数据
      stats.total = 22
      stats.online = 20
      stats.offline = 2
      stats.working = 5
      stats.sensors = 1
      stats.cameras = 1
      stats.gateways = 2
      stats.others = 18
    }
    
    return stats
  }

  /**
   * 获取报警统计
   */
  async getAlarmStats(): Promise<AlarmStats> {
    const stats = new AlarmStats()
    
    try {
      const alarms = await this.alarmService.getAlarmList()
      stats.total = alarms.length
      stats.unprocessed = alarms.filter(a => !a.isRead).length
      stats.processed = alarms.filter(a => a.isRead).length
      
      // 计算今日报警数
      const today = new Date().toDateString()
      stats.todayCount = alarms.filter(a => new Date(a.time).toDateString() === today).length
      
    } catch (error) {
      console.error('[StatsService] 获取报警统计失败:', error)
    }
    
    return stats
  }

  /**
   * 获取灌溉统计
   */
  async getIrrigationStats(): Promise<IrrigationStats> {
    const stats = new IrrigationStats()
    
    try {
      const totalWater = await this.irrigationService.getTotalWaterAmount()
      stats.totalWater = totalWater
      
      const history = await this.irrigationService.getIrrigationHistory()
      stats.totalDuration = history.reduce((sum, r) => sum + r.duration, 0)
      stats.autoCount = history.filter(r => r.mode.toString() === '自动灌溉').length
      stats.manualCount = history.filter(r => r.mode.toString() === '手动灌溉').length
      
      // 计算今日灌溉次数
      const today = new Date().toDateString()
      stats.todayCount = history.filter(r => new Date(r.startTime).toDateString() === today).length
      
    } catch (error) {
      console.error('[StatsService] 获取灌溉统计失败:', error)
    }
    
    return stats
  }

  /**
   * 获取控制流程统计
   */
  async getControlStats(): Promise<ControlStats> {
    const stats = new ControlStats()
    
    try {
      const result = await HttpClient.get<ApiResponse<ControlStats>>('/api/control/stats')
      if (result.code === 200 && result.data) {
        stats.totalSuccess = result.data.totalSuccess
        stats.totalFailed = result.data.totalFailed
        stats.running = result.data.running
        stats.userTriggered = result.data.userTriggered
      }
    } catch (error) {
      console.warn('[StatsService] 获取控制统计失败，使用默认值')
      // 模拟数据
      stats.totalSuccess = 55
      stats.totalFailed = 367
      stats.running = 0
      stats.userTriggered = 1
    }
    
    return stats
  }

  /**
   * 获取任务统计
   */
  async getTaskStats(): Promise<TaskStats> {
    const stats = new TaskStats()
    
    try {
      const result = await HttpClient.get<ApiResponse<TaskStats>>('/api/task/stats')
      if (result.code === 200 && result.data) {
        const data = result.data
        stats.total = data.total
        stats.completed = data.completed
        stats.pending = data.pending
        stats.overdue = data.overdue
        stats.unassigned = data.unassigned
        stats.inProgress = data.inProgress
      }
    } catch (error) {
      console.warn('[StatsService] 获取任务统计失败，使用默认值')
      // 模拟数据
      stats.total = 12
      stats.completed = 3
      stats.pending = 3
      stats.overdue = 3
      stats.unassigned = 0
      stats.inProgress = 3
    }
    
    return stats
  }

  /**
   * 获取溯源统计
   */
  async getTraceStats(): Promise<TraceStats> {
    const stats = new TraceStats()
    
    try {
      const result = await HttpClient.get<ApiResponse<TraceStats>>('/api/trace/stats')
      if (result.code === 200 && result.data) {
        const data = result.data
        stats.totalScans = data.totalScans
        stats.productCount = data.productCount
        stats.batchCount = data.batchCount
        stats.topLocations = data.topLocations
        stats.topProducts = data.topProducts
      }
    } catch (error) {
      console.warn('[StatsService] 获取溯源统计失败，使用默认值')
    }
    
    return stats
  }

  /**
   * 获取基地信息
   */
  getMockBaseInfo(): BaseInfo {
    return {
      name: '智慧农业实验基地',
      manager: '唐工',
      phone: '--',
      area: 1800,
      plotCount: 35,
      cropCount: 5,
      batchCount: 10
    }
  }
}
