import { Farm, MonitorPoint, CropPlanting, CropStageConfig, CropType } from '../models/Farm'
import { HttpClient } from '../web/HttpClient'

/**
 * API响应结构
 */
interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 农场服务
 * 注：由 FieldService 重命名为 FarmService
 */
export class FarmService {
  
  /**
   * 获取所有农场列表
   */
  async getFarmList(activeOnly: boolean = true): Promise<Farm[]> {
    try {
      let result = await HttpClient.get<ApiResponse<Farm[]>>(
        `/api/farms?activeOnly=${activeOnly}`
      )
      return result.data || []
    } catch (error) {
      console.error('获取农场列表失败:', error)
      return []
    }
  }

  /**
   * 获取农场详情（含检测点）
   */
  async getFarmDetail(id: number): Promise<FarmDetail | null> {
    try {
      let result = await HttpClient.get<ApiResponse<FarmDetail>>(
        `/api/farms/${id}`
      )
      return result.data || null
    } catch (error) {
      console.error('获取农场详情失败:', error)
      return null
    }
  }

  /**
   * 获取农场下的检测点列表
   */
  async getFarmPoints(farmId: number): Promise<MonitorPoint[]> {
    try {
      let result = await HttpClient.get<ApiResponse<MonitorPoint[]>>(
        `/api/farms/${farmId}/points`
      )
      return result.data || []
    } catch (error) {
      console.error('获取检测点列表失败:', error)
      return []
    }
  }

  /**
   * 获取检测点列表
   */
  async getPointList(farmId?: number, activeOnly: boolean = true): Promise<MonitorPoint[]> {
    try {
      let url = `/api/points?activeOnly=${activeOnly}`
      if (farmId !== undefined) {
        url += `&farmId=${farmId}`
      }
      let result = await HttpClient.get<ApiResponse<MonitorPoint[]>>(url)
      return result.data || []
    } catch (error) {
      console.error('获取检测点列表失败:', error)
      return []
    }
  }

  /**
   * 获取检测点详情
   */
  async getPointDetail(pointId: number): Promise<MonitorPoint | null> {
    try {
      let result = await HttpClient.get<ApiResponse<MonitorPoint>>(
        `/api/points/${pointId}`
      )
      return result.data || null
    } catch (error) {
      console.error('获取检测点详情失败:', error)
      return null
    }
  }

  /**
   * 获取检测点的作物种植信息
   */
  async getCropPlanting(pointId: number): Promise<CropPlanting | null> {
    try {
      let result = await HttpClient.get<ApiResponse<CropPlanting>>(
        `/api/points/${pointId}/crop`
      )
      return result.data || null
    } catch (error) {
      console.error('获取作物种植信息失败:', error)
      return null
    }
  }

  /**
   * 获取作物生长阶段配置
   */
  async getCropStageConfigs(cropCode: string): Promise<CropStageConfig[]> {
    try {
      let result = await HttpClient.get<ApiResponse<CropStageConfig[]>>(
        `/api/smart-irrigation/crop/stages?cropType=${cropCode}`
      )
      return result.data || []
    } catch (error) {
      console.error('获取作物阶段配置失败:', error)
      return []
    }
  }

  /**
   * 创建农场
   */
  async createFarm(farm: Partial<Farm>): Promise<Farm | null> {
    try {
      let result = await HttpClient.post<ApiResponse<Farm>>(
        '/api/farms',
        farm
      )
      return result.data || null
    } catch (error) {
      console.error('创建农场失败:', error)
      return null
    }
  }

  /**
   * 更新农场
   */
  async updateFarm(id: number, farm: Partial<Farm>): Promise<Farm | null> {
    try {
      let result = await HttpClient.put<ApiResponse<Farm>>(
        `/api/farms/${id}`,
        farm
      )
      return result.data || null
    } catch (error) {
      console.error('更新农场失败:', error)
      return null
    }
  }

  /**
   * 删除农场
   */
  async deleteFarm(id: number): Promise<boolean> {
    try {
      await HttpClient.delete<ApiResponse<void>>(`/api/farms/${id}`)
      return true
    } catch (error) {
      console.error('删除农场失败:', error)
      return false
    }
  }
}

/**
 * 农场详情（含检测点）
 */
export interface FarmDetail {
  farm: Farm
  points: MonitorPoint[]
}

// 导出别名，兼容旧代码
export { FarmService as FieldService }
export { Farm as Field }
export type { FarmDetail as FieldDetail }
