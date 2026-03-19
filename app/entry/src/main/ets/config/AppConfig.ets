/**
 * 全局应用配置管理器
 * 用于控制模拟模式、测试模式等全局开关
 * 
 * 使用方式：
 * - 开发测试阶段：设置 simulationMode = true，使用模拟数据
 * - 接入硬件后：设置 simulationMode = false，连接真实服务器
 */
export class AppConfig {
  private static instance: AppConfig

  /**
   * 模拟模式开关
   * true: 使用模拟数据（开发测试）
   * false: 连接真实服务器（生产环境）
   */
  private _simulationMode: boolean = true

  /**
   * 是否显示模拟模式提示
   */
  private _showSimulationHint: boolean = true

  /**
   * 是否记录模拟灌溉到历史
   */
  private _recordSimulatedIrrigation: boolean = true

  /**
   * 模拟数据刷新间隔（毫秒）
   */
  private _simulationRefreshInterval: number = 5000

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): AppConfig {
    if (!AppConfig.instance) {
      AppConfig.instance = new AppConfig()
    }
    return AppConfig.instance
  }

  /**
   * 获取模拟模式状态
   */
  get simulationMode(): boolean {
    return this._simulationMode
  }

  /**
   * 设置模拟模式状态
   */
  set simulationMode(value: boolean) {
    this._simulationMode = value
    console.log(`[AppConfig] 模拟模式已${value ? '开启' : '关闭'}`)
  }

  /**
   * 获取是否显示模拟提示
   */
  get showSimulationHint(): boolean {
    return this._showSimulationHint
  }

  /**
   * 设置是否显示模拟提示
   */
  set showSimulationHint(value: boolean) {
    this._showSimulationHint = value
  }

  /**
   * 获取是否记录模拟灌溉
   */
  get recordSimulatedIrrigation(): boolean {
    return this._recordSimulatedIrrigation
  }

  /**
   * 设置是否记录模拟灌溉
   */
  set recordSimulatedIrrigation(value: boolean) {
    this._recordSimulatedIrrigation = value
  }

  /**
   * 获取模拟数据刷新间隔
   */
  get simulationRefreshInterval(): number {
    return this._simulationRefreshInterval
  }

  /**
   * 设置模拟数据刷新间隔
   */
  set simulationRefreshInterval(value: number) {
    this._simulationRefreshInterval = value
  }

  /**
   * 开启模拟模式（便捷方法）
   */
  enableSimulation(): void {
    this.simulationMode = true
  }

  /**
   * 关闭模拟模式（便捷方法）
   */
  disableSimulation(): void {
    this.simulationMode = false
  }

  /**
   * 切换模拟模式
   */
  toggleSimulation(): boolean {
    this._simulationMode = !this._simulationMode
    console.log(`[AppConfig] 模拟模式已${this._simulationMode ? '开启' : '关闭'}`)
    return this._simulationMode
  }

  /**
   * 获取配置摘要
   */
  getConfigSummary(): string {
    return `模拟模式: ${this._simulationMode ? '开启' : '关闭'}, ` +
           `记录模拟灌溉: ${this._recordSimulatedIrrigation ? '是' : '否'}`
  }
}

/**
 * 全局配置实例快捷访问
 */
export const appConfig = AppConfig.getInstance()
