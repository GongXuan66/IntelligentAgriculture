import { Farm, MonitorPoint } from '../models/Farm'

/**
 * 全局应用状态
 * 管理当前选中的农场和检测点
 */
export class AppState {
  private static instance: AppState
  
  // 当前选中的农场
  currentFarm: Farm | null = null
  
  // 兼容旧版：currentField 别名
  get currentField(): Farm | null {
    return this.currentFarm
  }
  
  set currentField(value: Farm | null) {
    this.currentFarm = value
  }
  
  // 当前选中的检测点
  currentPoint: MonitorPoint | null = null
  
  // 农场列表
  farms: Farm[] = []
  
  // 兼容旧版：fields 别名
  get fields(): Farm[] {
    return this.farms
  }
  
  set fields(value: Farm[]) {
    this.farms = value
  }
  
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
   * 设置当前农场
   */
  setCurrentFarm(farm: Farm | null): void {
    this.currentFarm = farm
    // 切换农场时清空检测点
    this.currentPoint = null
    this.points = []
  }

  /**
   * 兼容旧版：设置当前地块
   */
  setCurrentField(field: Farm | null): void {
    this.setCurrentFarm(field)
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
   * 设置农场列表
   */
  setFarms(farms: Farm[]): void {
    this.farms = farms
    // 默认选中第一个启用的农场
    if (!this.currentFarm && farms.length > 0) {
      const activeFarms = farms.filter(f => f.status === 1 || f.status === undefined)
      if (activeFarms.length > 0) {
        this.currentFarm = activeFarms[0]
      }
    }
  }

  /**
   * 兼容旧版：设置地块列表
   */
  setFields(fields: Farm[]): void {
    this.setFarms(fields)
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
    if (this.currentFarm && this.currentPoint) {
      return `${this.currentFarm.farmName} - ${this.currentPoint.pointName}`
    } else if (this.currentFarm) {
      return this.currentFarm.farmName
    }
    return '选择农场'
  }
}