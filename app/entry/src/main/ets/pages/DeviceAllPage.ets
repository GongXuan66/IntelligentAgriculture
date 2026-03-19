import { Device, DeviceStatus, DeviceType } from '../models/Device'
import { DeviceService } from '../services/DeviceService'
import { NavBottom } from '../components/NavBottom'

/**
 * 设备总览页面 - 显示所有设备
 */
@Entry
@Component
struct DeviceAllPage {
  @State deviceList: Device[] = []
  @State isLoading: boolean = true
  @State filterStatus: number = -1  // -1全部, 0离线, 1在线, 2工作中
  
  private deviceService: DeviceService = new DeviceService()

  aboutToAppear() {
    this.loadDevices()
  }

  async loadDevices() {
    try {
      this.deviceList = await this.deviceService.getDeviceList()
    } catch (error) {
      console.error('获取设备列表失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  async toggleDevice(device: Device, isOn: boolean): Promise<void> {
    let command = isOn ? 'on' : 'off'
    let success = await this.deviceService.controlDevice(device.deviceId, command)
    
    if (success) {
      await this.loadDevices()
    }
  }

  // 获取过滤后的设备
  private getFilteredDevices(deviceType: DeviceType): Device[] {
    let devices = this.deviceList.filter(d => d.deviceType === deviceType)
    
    if (this.filterStatus === 0) {
      devices = devices.filter(d => d.status === DeviceStatus.OFFLINE)
    } else if (this.filterStatus === 1) {
      devices = devices.filter(d => d.status === DeviceStatus.ONLINE)
    } else if (this.filterStatus === 2) {
      devices = devices.filter(d => d.status === DeviceStatus.WORKING)
    }
    
    return devices
  }

  build() {
    Column() {
      // 标题栏
      Column() {
        Row() {
          Text('设备管理')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Blank()

          Row() {
            Text('在线 ' + this.deviceList.filter(d => d.status !== DeviceStatus.OFFLINE).length)
              .fontSize(12)
              .fontColor('#4CAF50')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#E8F5E9')
          .borderRadius(12)
        }
        .width('100%')

        // 筛选按钮
        Row() {
          this.FilterButton('全部', -1)
          this.FilterButton('在线', 1)
          this.FilterButton('工作中', 2)
          this.FilterButton('离线', 0)
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 12 })
      .backgroundColor(Color.White)

      // 内容区域
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color('#4CAF50')
          Text('加载中...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 水泵列表
            this.DeviceTypeSection('💧 水泵', DeviceType.WATER_PUMP)
            
            // 补光灯列表
            this.DeviceTypeSection('☀️ 补光灯', DeviceType.LED)
            
            // 风扇列表
            this.DeviceTypeSection('🌬️ 风扇', DeviceType.FAN)
            
            // 水阀列表
            this.DeviceTypeSection('🔧 水阀', DeviceType.VALVE)
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 底部导航
      NavBottom({ currentIndex: 1 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  FilterButton(text: string, status: number) {
    Text(text)
      .fontSize(12)
      .fontColor(this.filterStatus === status ? '#FFFFFF' : '#666666')
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(this.filterStatus === status ? '#4CAF50' : '#F0F0F0')
      .borderRadius(16)
      .margin({ right: 8 })
      .onClick(() => {
        this.filterStatus = status
      })
  }

  @Builder
  DeviceTypeSection(title: string, deviceType: DeviceType) {
    Column() {
      Row() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Blank()
        
        Text(`${this.getFilteredDevices(deviceType).length}台`)
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')

      ForEach(this.getFilteredDevices(deviceType), (device: Device) => {
        this.DeviceCard(device)
      })
    }
    .width('100%')
    .margin({ bottom: 16 })
  }

  @Builder
  DeviceCard(device: Device) {
    Column() {
      Row() {
        Text(device.deviceName)
          .fontSize(15)
          .fontColor('#333333')
          .fontWeight(FontWeight.Medium)
        
        Blank()
        
        // 状态指示
        Row() {
          Circle()
            .width(6)
            .height(6)
            .fill(this.getStatusColor(device.status))
            .margin({ right: 4 })
          
          Text(this.getStatusText(device.status))
            .fontSize(12)
            .fontColor(this.getStatusColor(device.status))
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(this.getStatusColor(device.status) + '20')
        .borderRadius(10)
      }
      .width('100%')

      // 控制按钮
      Row() {
        Button('开启')
          .fontSize(12)
          .height(32)
          .backgroundColor(device.status === DeviceStatus.WORKING ? '#CCCCCC' : '#4CAF50')
          .enabled(device.status !== DeviceStatus.WORKING)
          .onClick(() => this.toggleDevice(device, true))

        Button('关闭')
          .fontSize(12)
          .height(32)
          .backgroundColor(device.status === DeviceStatus.OFFLINE ? '#CCCCCC' : '#F44336')
          .margin({ left: 8 })
          .enabled(device.status !== DeviceStatus.OFFLINE)
          .onClick(() => this.toggleDevice(device, false))
        
        Blank()
        
        Text(this.formatTime(device.lastUpdate))
          .fontSize(11)
          .fontColor('#999999')
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ top: 8 })
  }

  private getStatusColor(status: DeviceStatus): ResourceColor {
    switch (status) {
      case DeviceStatus.WORKING:
        return '#4CAF50'
      case DeviceStatus.ONLINE:
        return '#2196F3'
      default:
        return '#999999'
    }
  }

  private getStatusText(status: DeviceStatus): string {
    switch (status) {
      case DeviceStatus.WORKING:
        return '工作中'
      case DeviceStatus.ONLINE:
        return '在线'
      default:
        return '离线'
    }
  }

  private formatTime(timestamp: string): string {
    if (!timestamp) return '--'
    let date = new Date(timestamp)
    let hour = date.getHours().toString().padStart(2, '0')
    let minute = date.getMinutes().toString().padStart(2, '0')
    return `${hour}:${minute}`
  }
}