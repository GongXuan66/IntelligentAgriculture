import { VentilationService } from '../services/VentilationService'
import { SensorService } from '../services/SensorService'
import { DeviceService } from '../services/DeviceService'
import { Device, DeviceStatus, DeviceType } from '../models/Device'
import { AppConfig } from '../config/AppConfig'
import { NavBottom } from '../components/NavBottom'

class VentilationSample {
  time: string = ''
  temperature: number = 0
  co2: number = 0
  fanLevel: number = 0
}

/**
 * 通风管理页面 - 支持多风扇设备精细控制
 */
@Entry
@Component
struct VentilationPage {
  @State currentTemperature: number = -1
  @State currentCo2: number = -1
  @State currentHumidity: number = -1
  @State targetTemperature: number = 30
  @State targetCo2: number = 1000
  @State fanLevel: number = 0
  @State isAutoMode: boolean = true
  @State statusText: string = '等待数据采集...'
  @State lastUpdate: string = '--'
  @State samples: VentilationSample[] = []
  @State isSimulationMode: boolean = false

  // 设备相关状态
  @State fanList: Device[] = []
  @State selectedFanIds: string[] = []

  private readonly ventilationService: VentilationService = VentilationService.getInstance()
  private readonly sensorService: SensorService = new SensorService()
  private readonly deviceService: DeviceService = new DeviceService()
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private refreshInterval: number = -1
  private isAdjusting: boolean = false

  aboutToAppear() {
    this.isSimulationMode = this.appConfig.simulationMode
    this.targetTemperature = this.ventilationService.getTargetTemperature()
    this.targetCo2 = this.ventilationService.getTargetCo2()
    this.loadDevices()
    this.refreshData()
    this.refreshInterval = setInterval(() => {
      this.refreshData()
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
      this.fanList = allDevices.filter(d => d.deviceType === DeviceType.FAN)
      
      // 默认选中第一个设备
      if (this.selectedFanIds.length === 0 && this.fanList.length > 0) {
        this.selectedFanIds = [this.fanList[0].deviceId]
        this.fanLevel = this.ventilationService.getCurrentFanLevel(this.fanList[0].deviceId)
      }
    } catch (error) {
      console.error('加载风扇设备列表失败:', error)
    }
  }

  // 切换风扇选择
  private toggleFan(deviceId: string): void {
    const index = this.selectedFanIds.indexOf(deviceId)
    if (index >= 0) {
      this.selectedFanIds = this.selectedFanIds.filter(id => id !== deviceId)
    } else {
      this.selectedFanIds = [...this.selectedFanIds, deviceId]
    }
  }

  private async refreshData(): Promise<void> {
    try {
      let envData = await this.sensorService.getEnvironmentData()
      this.currentTemperature = envData.temperature
      this.currentCo2 = envData.co2
      this.currentHumidity = envData.humidity
      this.lastUpdate = this.formatTime(envData.timestamp)
      this.appendSample(this.lastUpdate, this.currentTemperature, this.currentCo2, this.fanLevel)

      if (this.isAutoMode && !this.isAdjusting && this.currentTemperature >= 0 && this.currentCo2 >= 0 && this.selectedFanIds.length > 0) {
        this.isAdjusting = true
        try {
          let result = await this.ventilationService.adjustFanByTarget(this.targetTemperature, this.targetCo2, 1, this.selectedFanIds)
          this.fanLevel = result.nextFanLevel
          this.statusText = result.message
        } finally {
          this.isAdjusting = false
        }
      } else if (!this.isAutoMode) {
        this.statusText = `手动模式，风扇档位 ${this.fanLevel}%`
      }
    } catch (error) {
      this.statusText = '通风采集失败'
      this.currentTemperature = -1
      this.currentCo2 = -1
      this.currentHumidity = -1
    }
  }

  private appendSample(time: string, temperature: number, co2: number, fanLevel: number): void {
    if (temperature < 0 || co2 < 0) {
      return
    }

    let current: VentilationSample[] = []
    for (let i = 0; i < this.samples.length && i < 7; i++) {
      current.push(this.samples[i])
    }

    let sample = new VentilationSample()
    sample.time = time
    sample.temperature = temperature
    sample.co2 = co2
    sample.fanLevel = fanLevel

    let nextSamples: VentilationSample[] = [sample]
    for (let i = 0; i < current.length; i++) {
      nextSamples.push(current[i])
    }
    this.samples = nextSamples
  }

  private async runAutoControlNow(): Promise<void> {
    if (this.selectedFanIds.length === 0) {
      this.statusText = '请先选择风扇设备'
      return
    }
    try {
      let result = await this.ventilationService.adjustFanByTarget(this.targetTemperature, this.targetCo2, 1, this.selectedFanIds)
      this.fanLevel = result.nextFanLevel
      this.statusText = result.message
    } catch (error) {
      this.statusText = '自动通风执行失败'
    }
  }

  private async applyManualFanLevel(): Promise<void> {
    if (this.isAutoMode) {
      return
    }
    if (this.selectedFanIds.length === 0) {
      this.statusText = '请先选择风扇设备'
      return
    }

    try {
      let success = await this.ventilationService.setFanLevel(this.fanLevel, this.selectedFanIds)
      this.statusText = success ? `手动风扇档位已设置：${this.fanLevel}% (${this.selectedFanIds.length}个设备)` : '手动设置失败'
    } catch (error) {
      this.statusText = '手动设置失败'
    }
  }

  build() {
    Column() {
      Row() {
        Text('通风管理')
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
          this.CurrentSection()
          this.DeviceSelectorSection()
          this.AutoControlSection()
          this.ManualControlSection()
          this.SampleSection()
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      NavBottom({ currentIndex: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  CurrentSection() {
    Column() {
      Text('实时通风状态')
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')

      Row() {
        Column() {
          Text(this.currentTemperature >= 0 ? this.currentTemperature.toFixed(1) : '--')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getTemperatureColor())
          Text('温度 ℃')
            .fontSize(12)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
        .layoutWeight(1)

        Column() {
          Text(this.currentCo2 >= 0 ? this.currentCo2.toFixed(0) : '--')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getCo2Color())
          Text('CO₂ ppm')
            .fontSize(12)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 12 })

      Row() {
        Text(`湿度 ${this.currentHumidity >= 0 ? this.currentHumidity.toFixed(1) : '--'}%`)
          .fontSize(12)
          .fontColor('#666666')
        Blank()
        Text(`风扇 ${this.fanLevel}%`)
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
        Text('风扇设备选择')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()

        Text(`${this.selectedFanIds.length} 个设备`)
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')

      if (this.fanList.length === 0) {
        Text('暂无风扇设备')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
      } else {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.fanList, (device: Device) => {
            Row() {
              Checkbox({
                name: device.deviceId,
                group: 'fans'
              })
                .select(this.selectedFanIds.indexOf(device.deviceId) >= 0)
                .selectedColor('#03A9F4')
                .onChange((isChecked: boolean) => {
                  this.toggleFan(device.deviceId)
                })

              Text(device.deviceName)
                .fontSize(13)
                .fontColor('#333333')
                .margin({ left: 6 })

              Circle()
                .width(6)
                .height(6)
                .fill(device.status === DeviceStatus.WORKING ? '#4CAF50' : 
                      device.status === DeviceStatus.ONLINE ? '#03A9F4' : '#999999')
                .margin({ left: 6 })
            }
            .height(36)
            .padding({ left: 8, right: 12 })
            .backgroundColor(this.selectedFanIds.indexOf(device.deviceId) >= 0 ? '#E1F5FE' : '#F5F5F5')
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
              this.selectedFanIds = this.fanList.map(d => d.deviceId)
            })

          Button('取消')
            .fontSize(12)
            .height(28)
            .backgroundColor('#E0E0E0')
            .fontColor('#666666')
            .margin({ left: 8 })
            .onClick(() => {
              this.selectedFanIds = []
            })

          Button('全部开启')
            .fontSize(12)
            .height(28)
            .backgroundColor('#4CAF50')
            .fontColor(Color.White)
            .margin({ left: 8 })
            .onClick(async () => {
              const allIds = this.fanList.map(d => d.deviceId)
              await this.ventilationService.turnOnFan(allIds)
              this.fanLevel = 100
              this.statusText = '已开启所有风扇'
              await this.loadDevices()
            })

          Button('全部关闭')
            .fontSize(12)
            .height(28)
            .backgroundColor('#F44336')
            .fontColor(Color.White)
            .margin({ left: 8 })
            .onClick(async () => {
              const allIds = this.fanList.map(d => d.deviceId)
              await this.ventilationService.turnOffFan(allIds)
              this.fanLevel = 0
              this.statusText = '已关闭所有风扇'
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
        Text('自动通风')
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
        Text(`温度目标：${this.targetTemperature} ℃`)
          .fontSize(14)
          .fontColor('#666666')
        Blank()
      }
      .width('100%')
      .margin({ top: 14 })

      Slider({
        value: this.targetTemperature,
        min: 20,
        max: 38,
        step: 1
      })
        .width('100%')
        .margin({ top: 8 })
        .blockColor('#4CAF50')
        .trackColor('#E0E0E0')
        .selectedColor('#4CAF50')
        .onChange((value: number) => {
          this.targetTemperature = Math.round(value)
          this.ventilationService.setTargetTemperature(this.targetTemperature)
        })

      Row() {
        Text(`CO₂目标：${this.targetCo2} ppm`)
          .fontSize(14)
          .fontColor('#666666')
        Blank()
      }
      .width('100%')
      .margin({ top: 12 })

      Slider({
        value: this.targetCo2,
        min: 700,
        max: 1800,
        step: 50
      })
        .width('100%')
        .margin({ top: 8 })
        .blockColor('#4CAF50')
        .trackColor('#E0E0E0')
        .selectedColor('#4CAF50')
        .onChange((value: number) => {
          this.targetCo2 = Math.round(value)
          this.ventilationService.setTargetCo2(this.targetCo2)
        })

      Button(this.selectedFanIds.length === 0 ? '请先选择设备' : '立即执行自动通风')
        .width('100%')
        .height(40)
        .margin({ top: 14 })
        .backgroundColor(this.selectedFanIds.length === 0 ? '#CCCCCC' : '#4CAF50')
        .enabled(this.currentTemperature >= 0 && this.currentCo2 >= 0 && this.selectedFanIds.length > 0)
        .onClick(() => this.runAutoControlNow())

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
        Text('手动风扇调节')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        Blank()
        Text(`${this.fanLevel}%`)
          .fontSize(14)
          .fontColor('#03A9F4')
      }
      .width('100%')

      Slider({
        value: this.fanLevel,
        min: 0,
        max: 100,
        step: 1
      })
        .width('100%')
        .margin({ top: 14 })
        .blockColor('#03A9F4')
        .trackColor('#E0E0E0')
        .selectedColor('#03A9F4')
        .onChange((value: number) => {
          this.fanLevel = Math.round(value)
        })

      Button(this.isAutoMode ? '请先关闭自动模式' : 
             this.selectedFanIds.length === 0 ? '请先选择设备' : '应用手动档位')
        .width('100%')
        .height(40)
        .margin({ top: 14 })
        .backgroundColor(this.isAutoMode || this.selectedFanIds.length === 0 ? '#CCCCCC' : '#03A9F4')
        .enabled(!this.isAutoMode && this.selectedFanIds.length > 0)
        .onClick(() => this.applyManualFanLevel())
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

      if (this.samples.length === 0) {
        Text('暂无采样数据')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
      } else {
        ForEach(this.samples, (sample: VentilationSample) => {
          Row() {
            Text(sample.time)
              .fontSize(12)
              .fontColor('#999999')
            Blank()
            Text(`${sample.temperature.toFixed(1)}℃ / ${sample.co2.toFixed(0)}ppm / 风扇${sample.fanLevel}%`)
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
    .margin({ top: 12, bottom: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  private getTemperatureColor(): ResourceColor {
    if (this.currentTemperature < 0) {
      return '#999999'
    }
    if (this.currentTemperature > this.targetTemperature + 2) {
      return '#F44336'
    }
    if (this.currentTemperature > this.targetTemperature) {
      return '#FF9800'
    }
    return '#4CAF50'
  }

  private getCo2Color(): ResourceColor {
    if (this.currentCo2 < 0) {
      return '#999999'
    }
    if (this.currentCo2 > this.targetCo2 + 200) {
      return '#F44336'
    }
    if (this.currentCo2 > this.targetCo2) {
      return '#FF9800'
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