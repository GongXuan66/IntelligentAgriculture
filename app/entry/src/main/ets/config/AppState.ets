import { Field, MonitorPoint } from '../models/Field'

/**
 * 全局应用状态
 * 管理当前选中的地块和检测点
 */
export class AppState {
  private static instance: AppState
  
  // 当前选中的地块
  currentField: Field | null = null
  
  // 当前选中的检测点
  currentPoint: MonitorPoint | null = null
  
  // 地块列表
  fields: Field[] = []
  
  // 检测点列表
  points: MonitorPoint[] = []
  
  // 当前检测点ID（用于API请求）
  currentPointId: number = 1

  static getInstance(): AppState {
    if (!AppState.instance) {
      AppState.instance = new AppState()
    }
    return AppState.instance
  }

  /**
   * 设置当前地块
   */
  setCurrentField(field: Field | null): void {
    this.currentField = field
    // 切换地块时清空检测点
    this.currentPoint = null
    this.points = []
  }

  /**
   * 设置当前检测点
   */
  setCurrentPoint(point: MonitorPoint | null): void {
    this.currentPoint = point
    if (point?.id) {
      this.currentPointId = point.id
    }
  }

  /**
   * 设置地块列表
   */
  setFields(fields: Field[]): void {
    this.fields = fields
    // 默认选中第一个启用的地块
    if (!this.currentField && fields.length > 0) {
      const activeFields = fields.filter(f => f.status === 1 || f.status === undefined)
      if (activeFields.length > 0) {
        this.currentField = activeFields[0]
      }
    }
  }

  /**
   * 设置检测点列表
   */
  setPoints(points: MonitorPoint[]): void {
    this.points = points
    // 默认选中第一个启用的检测点
    if (!this.currentPoint && points.length > 0) {
      const activePoints = points.filter(p => p.status === 1 || p.status === undefined)
      if (activePoints.length > 0) {
        this.currentPoint = activePoints[0]
        if (activePoints[0].id) {
          this.currentPointId = activePoints[0].id!
        }
      }
    }
  }

  /**
   * 获取当前显示名称
   */
  getDisplayName(): string {
    if (this.currentField && this.currentPoint) {
      return `${this.currentField.fieldName} - ${this.currentPoint.pointName}`
    } else if (this.currentField) {
      return this.currentField.fieldName
    }
    return '选择地块'
  }
}
