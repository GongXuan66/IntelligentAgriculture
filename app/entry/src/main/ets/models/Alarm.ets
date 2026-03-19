/**
 * 报警记录模型
 */
export class AlarmRecord {
  id: string = ''
  alarmType: AlarmType = AlarmType.TEMPERATURE_HIGH
  alarmValue: number = 0
  threshold: number = 0
  time: string = ''
  isRead: boolean = false
}

/**
 * 报警类型枚举
 */
export enum AlarmType {
  TEMPERATURE_HIGH = '温度过高',
  TEMPERATURE_LOW = '温度过低',
  HUMIDITY_HIGH = '湿度过高',
  HUMIDITY_LOW = '湿度过低',
  LIGHT_LOW = '光照不足',
  CO2_HIGH = 'CO2浓度过高',
  SOIL_MOISTURE_LOW = '土壤湿度过低',
  DEVICE_OFFLINE = '设备离线'
}

/**
 * 报警配置
 */
export class AlarmConfig {
  enableTemperatureAlarm: boolean = true
  enableHumidityAlarm: boolean = true
  enableLightAlarm: boolean = true
  enableCo2Alarm: boolean = true
  enableSoilMoistureAlarm: boolean = true
  enableDeviceAlarm: boolean = true
}
