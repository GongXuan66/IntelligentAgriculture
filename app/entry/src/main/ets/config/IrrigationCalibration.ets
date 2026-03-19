/**
 * 灌溉统一标定参数
 * 用于保证自动灌溉计算与模拟引擎效果一致。
 */
export class IrrigationCalibration {
  /**
   * 水泵流量（升/秒）
   */
  static readonly FLOW_RATE_L_PER_SEC: number = 0.5

  /**
   * 每灌溉 1 升水带来的土壤湿度提升（%）
   */
  static readonly SOIL_MOISTURE_GAIN_PER_LITER: number = 1 / 0.6

  /**
   * 每灌溉 1 升水带来的空气湿度提升（%）
   */
  static readonly HUMIDITY_GAIN_PER_LITER: number = 0.3

  /**
   * 单次灌溉带来的土壤湿度最大提升（%）
   */
  static readonly MAX_SOIL_MOISTURE_GAIN: number = 35

  /**
   * 单次灌溉带来的空气湿度最大提升（%）
   */
  static readonly MAX_HUMIDITY_GAIN: number = 20
}
