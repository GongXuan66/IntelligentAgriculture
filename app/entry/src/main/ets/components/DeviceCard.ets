import { Device, DeviceStatus, DeviceType } from '../models/Device'

/**
 * 设备卡片组件
 */
@Component
export struct DeviceCard {
  @Prop device: Device = new Device()
  onToggle?: (device: Device, isOn: boolean) => void

  build() {
    Row() {
      // 设备图标
      Text(this.getDeviceIconText(this.device.deviceType))
        .fontSize(32)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)

      // 设备信息
      Column() {
        Text(this.device.deviceName)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Text(this.getStatusText(this.device.status))
          .fontSize(12)
          .fontColor(this.getStatusColor(this.device.status))
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      // 控制开关
      Toggle({
        type: ToggleType.Switch,
        isOn: this.device.status === DeviceStatus.WORKING
      })
        .selectedColor('#4CAF50')
        .onChange((isOn: boolean) => {
          if (this.onToggle) {
            this.onToggle(this.device, isOn)
          }
        })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({
      radius: 6,
      color: '#1a000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * 获取设备图标文字
   */
  private getDeviceIconText(type: DeviceType): string {
    switch (type) {
      case DeviceType.WATER_PUMP:
        return '🚿'
      case DeviceType.LED:
        return '💡'
      case DeviceType.FAN:
        return '🌀'
      case DeviceType.VALVE:
        return '🔧'
      default:
        return '📦'
    }
  }

  /**
   * 获取状态文本
   */
  private getStatusText(status: DeviceStatus): string {
    switch (status) {
      case DeviceStatus.ONLINE:
        return '在线'
      case DeviceStatus.OFFLINE:
        return '离线'
      case DeviceStatus.WORKING:
        return '工作中'
      default:
        return '未知'
    }
  }

  /**
   * 获取状态颜色
   */
  private getStatusColor(status: DeviceStatus): ResourceColor {
    switch (status) {
      case DeviceStatus.ONLINE:
        return '#4CAF50'
      case DeviceStatus.OFFLINE:
        return '#999999'
      case DeviceStatus.WORKING:
        return '#FF9800'
      default:
        return '#999999'
    }
  }
}