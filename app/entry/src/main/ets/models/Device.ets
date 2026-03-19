/**
 * 设备数据模型
 */
export class Device {
  deviceId: string = ''
  deviceName: string = ''
  deviceType: DeviceType = DeviceType.SENSOR
  status: DeviceStatus = DeviceStatus.OFFLINE
  lastUpdate: string = ''
}

/**
 * 设备类型枚举
 */
export enum DeviceType {
  SENSOR = 'sensor',       // 传感器
  WATER_PUMP = 'pump',     // 水泵
  VALVE = 'valve',         // 水阀
  LED = 'led',             // LED灯
  FAN = 'fan'              // 风扇
}

/**
 * 设备状态枚举
 */
export enum DeviceStatus {
  ONLINE = 'online',       // 在线
  OFFLINE = 'offline',     // 离线
  WORKING = 'working'      // 工作中
}

/**
 * 设备控制指令
 */
export interface DeviceCommand {
  deviceId: string
  command: string
  timestamp?: string
}
