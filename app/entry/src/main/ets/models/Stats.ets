/**
 * 统计数据模型
 */

/**
 * 基地概况信息
 */
export class BaseInfo {
  name: string = '智慧农业实验基地'
  manager: string = '唐工'
  phone: string = '--'
  area: number = 1800        // 面积(亩)
  plotCount: number = 35     // 地块数量
  cropCount: number = 5      // 种养作物数
  batchCount: number = 10    // 种植批次
}

/**
 * 设备统计数据
 */
export class DeviceStats {
  total: number = 0
  online: number = 0
  offline: number = 0
  working: number = 0
  
  // 按类型统计
  sensors: number = 0
  cameras: number = 0
  gateways: number = 0
  others: number = 0
}

/**
 * 控制流程统计
 */
export class ControlStats {
  totalSuccess: number = 0
  totalFailed: number = 0
  running: number = 0
  userTriggered: number = 0
}

/**
 * 任务统计
 */
export class TaskStats {
  total: number = 0
  completed: number = 0
  pending: number = 0
  overdue: number = 0
  unassigned: number = 0
  inProgress: number = 0
}

/**
 * 报警统计
 */
export class AlarmStats {
  total: number = 0
  unprocessed: number = 0
  processed: number = 0
  todayCount: number = 0
}

/**
 * 灌溉统计
 */
export class IrrigationStats {
  totalWater: number = 0       // 总用水量(升)
  totalDuration: number = 0    // 总灌溉时长(秒)
  todayCount: number = 0       // 今日灌溉次数
  autoCount: number = 0        // 自动灌溉次数
  manualCount: number = 0      // 手动灌溉次数
}

/**
 * 溯源统计数据
 */
export class TraceStats {
  totalScans: number = 0
  productCount: number = 0
  batchCount: number = 0
  topLocations: TraceLocationItem[] = []
  topProducts: TraceProductItem[] = []
}

/**
 * 溯源地点统计项
 */
export class TraceLocationItem {
  name: string = ''
  count: number = 0
  percentage: number = 0
}

/**
 * 溯源产品统计项
 */
export class TraceProductItem {
  name: string = ''
  count: number = 0
  percentage: number = 0
}

/**
 * 综合统计数据
 */
export class DashboardStats {
  baseInfo: BaseInfo = new BaseInfo()
  deviceStats: DeviceStats = new DeviceStats()
  controlStats: ControlStats = new ControlStats()
  taskStats: TaskStats = new TaskStats()
  alarmStats: AlarmStats = new AlarmStats()
  irrigationStats: IrrigationStats = new IrrigationStats()
  traceStats: TraceStats = new TraceStats()
}
