import { Device, DeviceStatus, DeviceType } from '../models/Device'
import { DeviceService } from '../services/DeviceService'
import { DeviceCard } from '../components/DeviceCard'
import { NavBottom } from '../components/NavBottom'

/**
 * 设备控制页面
 */
@Entry
@Component
struct DevicePage {
  @State deviceList: Device[] = []
  @State isLoading: boolean = true
  
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
      // 更新本地状态
      let index = this.deviceList.findIndex(d => d.deviceId === device.deviceId)
      if (index !== -1) {
        this.deviceList[index].status = isOn ? DeviceStatus.WORKING : DeviceStatus.ONLINE
        this.deviceList = [...this.deviceList] // 触发UI更新
      }
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('设备控制')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
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
        List() {
          ForEach(this.deviceList, (device: Device, index: number) => {
            ListItem() {
              DeviceCard({
                device: device,
                onToggle: (d: Device, isOn: boolean) => this.toggleDevice(d, isOn)
              })
            }
            .margin({ top: index === 0 ? 16 : 8, left: 16, right: 16 })
          })
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
}
