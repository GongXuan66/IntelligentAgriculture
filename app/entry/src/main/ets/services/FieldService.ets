import { Farm, MonitorPoint } from '../models/Farm'
import { FarmService, FarmDetail } from './FarmService'
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
 * 兼容旧版：Field 类型别名
 * 注：推荐使用 Farm 类型
 */
export type Field = Farm

/**
 * 兼容旧版：FieldDetail 类型别名
 * 注：推荐使用 FarmDetail 类型
 */
export type FieldDetail = FarmDetail

/**
 * 地块服务（兼容层）
 * 注：推荐直接使用 FarmService
 * 此类保留用于向后兼容，内部委托给 FarmService
 */
export class FieldService {
  private farmService: FarmService = new FarmService()
  
  /**
   * 获取所有地块列表
   * @deprecated 请使用 farmService.getFarmList()
   */
  async getFieldList(activeOnly: boolean = true): Promise<Field[]> {
    return this.farmService.getFarmList(activeOnly)
  }

  /**
   * 获取地块详情（含检测点）
   * @deprecated 请使用 farmService.getFarmDetail()
   */
  async getFieldDetail(id: number): Promise<FieldDetail | null> {
    return this.farmService.getFarmDetail(id)
  }

  /**
   * 获取地块下的检测点列表
   * @deprecated 请使用 farmService.getFarmPoints()
   */
  async getFieldPoints(farmId: number): Promise<MonitorPoint[]> {
    return this.farmService.getFarmPoints(farmId)
  }

  /**
   * 获取检测点列表
   */
  async getPointList(farmId?: number, activeOnly: boolean = true): Promise<MonitorPoint[]> {
    return this.farmService.getPointList(farmId, activeOnly)
  }
}