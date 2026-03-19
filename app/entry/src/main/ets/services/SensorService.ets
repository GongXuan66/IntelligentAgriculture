import { EnvironmentData, HistoryDataRecord } from '../models/EnvironmentData'
import { HttpClient } from '../web/HttpClient'
import { MockDataManager } from '../mock/MockDataManager'
import { AppConfig } from '../config/AppConfig'

/**
 * API响应结构
 */
interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 传感器数据服务
 * 
 * 数据流程：
 * 1. 始终从服务端数据库读取数据
 * 2. 模拟模式下，获取数据后设置基准，用于后续模拟计算
 * 3. 灌溉等操作时，模拟算法计算新值并上报到数据库
 */
export class SensorService {
  private mockManager: MockDataManager = MockDataManager.getInstance()
  private appConfig: AppConfig = AppConfig.getInstance()

  /**
   * 获取实时环境数据（始终从数据库读取）
   */
  async getEnvironmentData(pointId: number = 1): Promise<EnvironmentData> {
    try {
      let result = await HttpClient.get<ApiResponse<EnvironmentData>>(
        `/api/environment?pointId=${pointId}`
      )
      
      // 映射recordedAt到timestamp
      if (result.data.recordedAt && !result.data.timestamp) {
        result.data.timestamp = result.data.recordedAt
      }
      
      // 如果是模拟模式，设置基准数据用于后续模拟计算
      if (this.appConfig.simulationMode) {
        this.mockManager.setBaseData(result.data)
      }
      
      result.data.isConnected = true
      return result.data
    } catch (error) {
      console.error('获取环境数据失败:', error)
      
      // 返回离线状态的占位数据
      return {
        temperature: -1,
        humidity: -1,
        light: -1,
        co2: -1,
        soilMoisture: -1,
        timestamp: '',
        isConnected: false
      }
    }
  }

  /**
   * 检查服务器连接状态
   */
  async checkConnection(): Promise<boolean> {
    try {
      await HttpClient.get<ApiResponse<EnvironmentData>>('/api/environment?pointId=1')
      return true
    } catch (error) {
      return false
    }
  }

  /**
   * 获取历史数据
   */
  async getHistoryData(pointId: number = 1, limit: number = 100): Promise<HistoryDataRecord[]> {
    try {
      let result = await HttpClient.get<ApiResponse<HistoryDataRecord[]>>(
        `/api/environment/history?pointId=${pointId}&limit=${limit}`
      )
      // 映射 recordedAt 到 time 字段
      const records = result.data.map((item: HistoryDataRecord) => {
        if (item.recordedAt && !item.time) {
          item.time = item.recordedAt
        }
        return item
      })
      return records
    } catch (error) {
      console.error('获取历史数据失败:', error)
      return []
    }
  }

  /**
   * 按时间范围获取历史数据
   */
  async getHistoryDataByRange(
    pointId: number,
    startTime: string,
    endTime: string
  ): Promise<HistoryDataRecord[]> {
    try {
      let result = await HttpClient.get<ApiResponse<HistoryDataRecord[]>>(
        `/api/environment/history/range?pointId=${pointId}&startTime=${startTime}&endTime=${endTime}`
      )
      return result.data
    } catch (error) {
      console.error('获取历史数据失败:', error)
      return []
    }
  }
}
