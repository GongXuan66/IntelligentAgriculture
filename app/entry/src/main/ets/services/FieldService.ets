import { Field, MonitorPoint } from '../models/Field'
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
 * 地块服务
 */
export class FieldService {
  
  /**
   * 获取所有地块列表
   */
  async getFieldList(activeOnly: boolean = true): Promise<Field[]> {
    try {
      let result = await HttpClient.get<ApiResponse<Field[]>>(
        `/api/field/list?activeOnly=${activeOnly}`
      )
      return result.data || []
    } catch (error) {
      console.error('获取地块列表失败:', error)
      return []
    }
  }

  /**
   * 获取地块详情（含检测点）
   */
  async getFieldDetail(id: number): Promise<FieldDetail | null> {
    try {
      let result = await HttpClient.get<ApiResponse<FieldDetail>>(
        `/api/field/${id}`
      )
      return result.data || null
    } catch (error) {
      console.error('获取地块详情失败:', error)
      return null
    }
  }

  /**
   * 获取地块下的检测点列表
   */
  async getFieldPoints(fieldId: number): Promise<MonitorPoint[]> {
    try {
      let result = await HttpClient.get<ApiResponse<MonitorPoint[]>>(
        `/api/field/${fieldId}/points`
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
  async getPointList(fieldId?: number, activeOnly: boolean = true): Promise<MonitorPoint[]> {
    try {
      let url = `/api/point/list?activeOnly=${activeOnly}`
      if (fieldId !== undefined) {
        url += `&fieldId=${fieldId}`
      }
      let result = await HttpClient.get<ApiResponse<MonitorPoint[]>>(url)
      return result.data || []
    } catch (error) {
      console.error('获取检测点列表失败:', error)
      return []
    }
  }
}

/**
 * 地块详情（含检测点）
 */
export interface FieldDetail {
  field: Field
  points: MonitorPoint[]
}
