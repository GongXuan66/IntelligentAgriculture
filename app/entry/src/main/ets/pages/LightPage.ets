import { LightService } from '../services/LightService'
import { SensorService } from '../services/SensorService'
import { DeviceService } from '../services/DeviceService'
import { Device, DeviceStatus, DeviceType } from '../models/Device'
import { AppConfig } from '../config/AppConfig'
import { NavBottom } from '../components/NavBottom'

class LightSample {
  time: string = ''
  value: number = 0
}

/**
 * 光照管理页面 - 支持多LED设备精细控制
 */
@Entry
@Component
struct LightPage {
  @State currentLight: number = -1
  @State targetLight: number = 500
  @State ledBrightness: number = 0
  @State isAutoMode: boolean = true
  @State statusText: string = '等待数据采集...'
  @State lastUpdate: string = '--'
  @State lightSamples: LightSample[] = []
  @State isSimulationMode: boolean = false

  // 设备相关状态
  @State ledList: Device[] = []
  @State selectedLedIds: string[] = []

  private readonly lightService: LightService = LightService.getInstance()
  private readonly sensorService: SensorService = new SensorService()
  private readonly deviceService: DeviceService = new DeviceService()
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private refreshInterval: number = -1
  private isAdjusting: boolean = false

  aboutToAppear() {
    this.isSimulationMode = this.appConfig.simulationMode
    this.targetLight = this.lightService.getLightThreshold()
    this.loadDevices()
    this.refreshLightData()
    this.refreshInterval = setInterval(() => {
      this.refreshLightData()
    }, 5000)
  }

  aboutToDisappear() {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval)
    }
  }

  async loadDevices() {
    try {
      const allDevices = await this.deviceService.getDeviceList()
      this.ledList = allDevices.filter(d => d.deviceType === DeviceType.LED)
      
      // 默认选中第一个设备
      if (this.selectedLedIds.length === 0 && this.ledList.length > 0) {
        this.selectedLedIds = [this.ledList[0].deviceId]
        this.ledBrightness = this.lightService.getCurrentBrightness(this.ledList[0].deviceId)
      }
    } catch (error) {
      console.error('加载LED设备列表失败:', error)
    }
  }

  // 切换LED选择
  private toggleLed(deviceId: string): void {
    const index = this.selectedLedIds.indexOf(deviceId)
    if (index >= 0) {
      this.selectedLedIds = this.selectedLedIds.filter(id => id !== deviceId)
    } else {
      this.selectedLedIds = [...this.selectedLedIds, deviceId]
    }
  }

  private async refreshLightData(): Promise<void> {
    try {
      let envData = await this.sensorService.getEnvironmentData()
      this.currentLight = envData.light
      this.lastUpdate = this.formatTime(envData.timestamp)
      this.appendSample(this.currentLight, this.lastUpdate)

      if (this.isAutoMode && !this.isAdjusting && this.currentLight >= 0 && this.selectedLedIds.length > 0) {
        this.isAdjusting = true
        try {
          let result = await this.lightService.adjustBrightnessByTarget(this.targetLight, 1, this.selectedLedIds)
          this.ledBrightness = result.nextBrightness
          this.statusText = result.message
        } finally {
          this.isAdjusting = false
        }
      } else if (!this.isAutoMode) {
        this.statusText = `手动模式，LED亮度 ${this.ledBrightness}%`
      }
    } catch (error) {
      this.statusText = '光照采集失败'
      this.currentLight = -1
    }
  }

  private appendSample(value: number, time: string): void {
    if (value < 0) {
      return
    }
    let current: LightSample[] = []
    for (let i = 0; i < this.lightSamples.length && i < 7; i++) {
      current.push(this.lightSamples[i])
    }

    let sample = new LightSample()
    sample.time = time
    sample.value = value

    let nextSamples: LightSample[] = [sample]
    for (let i = 0; i < current.length; i++) {
      nextSamples.push(current[i])
    }
    this.lightSamples = nextSamples
  }

  private async runAutoAdjustNow(): Promise<void> {
    if (this.selectedLedIds.length === 0) {
      this.statusText = '请先选择LED设备'
      return
    }
    try {
      let result = await this.lightService.adjustBrightnessByTarget(this.targetLight, 1, this.selectedLedIds)
      this.ledBrightness = result.nextBrightness
      this.statusText = result.message
    } catch (error) {
      this.statusText = '自动调光失败'
    }
  }

  private async applyManualBrightness(): Promise<void> {
    if (this.isAutoMode) {
      return
    }
    if (this.selectedLedIds.length === 0) {
      this.statusText = '请先选择LED设备'
      return
    }

    try {
      let success = await this.lightService.setLedBrightness(this.ledBrightness, this.selectedLedIds)
      this.statusText = success ? `手动亮度已设置：${this.ledBrightness}% (${this.selectedLedIds.length}个设备)` : '手动设置失败'
    } catch (error) {
      this.statusText = '手动设置失败'
    }
  }

  build() {
    Column() {
      Row() {
        Text('光照管理')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Blank()

        Row() {
          Text(this.isSimulationMode ? '模拟' : '在线')
            .fontSize(12)
            .fontColor(this.isSimulationMode ? '#FF9800' : '#4CAF50')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(this.isSimulationMode ? '#FFF3E0' : '#E8F5E9')
        .borderRadius(4)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      Scroll() {
        Column() {
          this.CurrentLightSection()
          this.DeviceSelectorSection()
          this.AutoControlSection()
          this.ManualControlSection()
          this.SampleSection()
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      NavBottom({ currentIndex: 3 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  CurrentLightSection() {
    Column() {
      Text('实时光照强度')
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')

      Row() {
        Text(this.currentLight >= 0 ? this.currentLight.toFixed(0) : '--')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getLightColor())
        Text(' lux')
          .fontSize(18)
          .fontColor('#666666')
          .margin({ top: 20 })
      }
      .margin({ top: 12 })

      Progress({
        value: this.currentLight > 0 ? Math.min(this.currentLight, 2000) : 0,
        total: 2000,
        type: ProgressType.Linear
      })
        .width('100%')
        .height(8)
        .margin({ top: 12 })
        .color(this.getLightColor())
        .backgroundColor('#E0E0E0')

      Row() {
        Text(`目标 ${this.targetLight} lux`)
          .fontSize(12)
          .fontColor('#666666')
        Blank()
        Text(`补光灯 ${this.ledBrightness}%`)
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')
      .margin({ top: 10 })

      Text(`更新时间 ${this.lastUpdate}`)
        .fontSize(12)
        .fontColor('#999999')
        .width('100%')
        .margin({ top: 6 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  DeviceSelectorSection() {
    Column() {
      Row() {
        Text('LED设备选择')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()

        Text(`${this.selectedLedIds.length} 个设备`)
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')

      if (this.ledList.length === 0) {
        Text('暂无LED设备')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.ledList, (device: Device) => {
            Row() {
              Checkbox({
                name: device.deviceId,
                group: 'leds'
              })
                .select(this.selectedLedIds.indexOf(device.deviceId) >= 0)
                .selectedColor('#FF9800')
                .onChange((isChecked: boolean) => {
                  this.toggleLed(device.deviceId)
                })

              Text(device.deviceName)
                .fontSize(13)
                .fontColor('#333333')
                .margin({ left: 6 })

              Circle()
                .width(6)
                .height(6)
                .fill(device.status === DeviceStatus.WORKING ? '#4CAF50' : 
                      device.status === DeviceStatus.ONLINE ? '#FF9800' : '#999999')
                .margin({ left: 6 })
            }
            .height(36)
            .padding({ left: 8, right: 12 })
            .backgroundColor(this.selectedLedIds.indexOf(device.deviceId) >= 0 ? '#FFF3E0' : '#F5F5F5')
            .borderRadius(18)
            .margin({ right: 8, top: 8 })
          })
        }

        // 快捷操作
        Row() {
          Button('全选')
            .fontSize(12)
            .height(28)
            .backgroundColor('#E0E0E0')
            .fontColor('#666666')
            .onClick(() => {
              this.selectedLedIds = this.ledList.map(d => d.deviceId)
            })

          Button('取消')
            .fontSize(12)
            .height(28)
            .backgroundColor('#E0E0E0')
            .fontColor('#666666')
            .margin({ left: 8 })
            .onClick(() => {
              this.selectedLedIds = []
            })

          Button('全部开启')
            .fontSize(12)
            .height(28)
            .backgroundColor('#4CAF50')
            .fontColor(Color.White)
            .margin({ left: 8 })
            .onClick(async () => {
              const allIds = this.ledList.map(d => d.deviceId)
              await this.lightService.turnOnLed(allIds)
              this.ledBrightness = 100
              this.statusText = '已开启所有LED'
              await this.loadDevices()
            })

          Button('全部关闭')
            .fontSize(12)
            .height(28)
            .backgroundColor('#F44336')
            .fontColor(Color.White)
            .margin({ left: 8 })
            .onClick(async () => {
              const allIds = this.ledList.map(d => d.deviceId)
              await this.lightService.turnOffLed(allIds)
              this.ledBrightness = 0
              this.statusText = '已关闭所有LED'
              await this.loadDevices()
            })
        }
        .width('100%')
        .margin({ top: 12 })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  AutoControlSection() {
    Column() {
      Row() {
        Text('自动补光')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()

        Toggle({ type: ToggleType.Switch, isOn: this.isAutoMode })
          .selectedColor('#4CAF50')
          .onChange((isOn: boolean) => {
            this.isAutoMode = isOn
            this.statusText = isOn ? '自动模式已开启' : '已切换为手动模式'
          })
      }
      .width('100%')

      Row() {
        Text(`目标值：${this.targetLight} lux`)
          .fontSize(14)
          .fontColor('#666666')
        Blank()
      }
      .width('100%')
      .margin({ top: 14 })

      Slider({
        value: this.targetLight,
        min: 200,
        max: 1200,
        step: 10
      })
        .width('100%')
        .margin({ top: 8 })
        .blockColor('#4CAF50')
        .trackColor('#E0E0E0')
        .selectedColor('#4CAF50')
        .onChange((value: number) => {
          this.targetLight = Math.round(value)
          this.lightService.setLightThreshold(this.targetLight)
        })

      Button(this.selectedLedIds.length === 0 ? '请先选择设备' : '立即执行自动调光')
        .width('100%')
        .height(40)
        .margin({ top: 14 })
        .backgroundColor(this.selectedLedIds.length === 0 ? '#CCCCCC' : '#4CAF50')
        .enabled(this.currentLight >= 0 && this.selectedLedIds.length > 0)
        .onClick(() => this.runAutoAdjustNow())

      Text(this.statusText)
        .fontSize(12)
        .fontColor('#1976D2')
        .width('100%')
        .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  ManualControlSection() {
    Column() {
      Row() {
        Text('手动亮度调节')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Blank()
        Text(`${this.ledBrightness}%`)
          .fontSize(14)
          .fontColor('#FF9800')
      }
      .width('100%')

      Slider({
        value: this.ledBrightness,
        min: 0,
        max: 100,
        step: 1
      })
        .width('100%')
        .margin({ top: 14 })
        .blockColor('#FF9800')
        .trackColor('#E0E0E0')
        .selectedColor('#FF9800')
        .onChange((value: number) => {
          this.ledBrightness = Math.round(value)
        })

      Button(this.isAutoMode ? '请先关闭自动模式' : 
             this.selectedLedIds.length === 0 ? '请先选择设备' : '应用手动亮度')
        .width('100%')
        .height(40)
        .margin({ top: 14 })
        .backgroundColor(this.isAutoMode || this.selectedLedIds.length === 0 ? '#CCCCCC' : '#FF9800')
        .enabled(!this.isAutoMode && this.selectedLedIds.length > 0)
        .onClick(() => this.applyManualBrightness())
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  SampleSection() {
    Column() {
      Text('最近采样记录')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')

      if (this.lightSamples.length === 0) {
        Text('暂无采样数据')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
      } else {
        ForEach(this.lightSamples, (sample: LightSample) => {
          Row() {
            Text(sample.time)
              .fontSize(12)
              .fontColor('#999999')
            Blank()
            Text(`${sample.value.toFixed(0)} lux`)
              .fontSize(13)
              .fontColor('#333333')
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({
            width: { bottom: 1 },
            color: '#f0f0f0'
          })
        })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  private getLightColor(): ResourceColor {
    if (this.currentLight < 0) {
      return '#999999'
    }
    if (this.currentLight < 300) {
      return '#FF9800'
    }
    if (this.currentLight > 1200) {
      return '#03A9F4'
    }
    return '#4CAF50'
  }

  private formatTime(timestamp: string): string {
    if (!timestamp) {
      return '--'
    }
    let date = new Date(timestamp)
    let hour = date.getHours().toString().padStart(2, '0')
    let minute = date.getMinutes().toString().padStart(2, '0')
    let second = date.getSeconds().toString().padStart(2, '0')
    return `${hour}:${minute}:${second}`
  }
}