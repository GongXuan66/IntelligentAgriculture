import { Device, DeviceStatus, DeviceType } from '../models/Device'
import { DeviceService } from '../services/DeviceService'
import { DeviceCard } from '../components/DeviceCard'
import { AppState } from '../config/AppState'
import router from '@ohos.router'

/**
 * 设备控制页面
 */
@Entry
@Component
struct DevicePage {
  @State deviceList: Device[] = []
  @State isLoading: boolean = true
  @State currentPointName: string = ''
  
  private deviceService: DeviceService = new DeviceService()
  private appState: AppState = AppState.getInstance()

  aboutToAppear() {
    // 检查是否有选中的检测点
    if (!this.appState.currentPoint) {
      // 没有选中检测点，返回地块总览页
      router.replaceUrl({ url: 'pages/Index' })
      return
    }
    
    this.currentPointName = this.appState.currentPoint.pointName
    this.loadDevices()
  }

  async loadDevices() {
    try {
      const pointId = this.appState.currentPoint?.id
      if (pointId) {
        this.deviceList = await this.deviceService.getDeviceList(pointId)
      } else {
        this.deviceList = []
      }
    } catch (error) {
      console.error('获取设备列表失败:', error)
      this.deviceList = []
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
      Column() {
        Row() {
          // 返回按钮
          Row() {
            Text('←')
              .fontSize(20)
              .fontColor('#333333')
          }
          .width(36)
          .height(36)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#f5f5f5')
          .borderRadius(18)
          .onClick(() => {
            router.back()
          })
          
          Text('设备控制')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ left: 12 })
          
          Blank()
        }
        .width('100%')
        
        // 当前检测点
        if (this.currentPointName) {
          Text(`📍 ${this.currentPointName}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
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
      } else if (this.deviceList.length === 0) {
        Column() {
          Text('🔧')
            .fontSize(48)
          Text('该检测点暂无设备')
            .fontSize(16)
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }
}
