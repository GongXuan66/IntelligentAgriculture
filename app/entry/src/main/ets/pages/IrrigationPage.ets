import { IrrigationConfig, IrrigationMode, IrrigationRecord } from '../models/Irrigation'
import { IrrigationService } from '../services/IrrigationService'
import { SensorService } from '../services/SensorService'
import { DeviceService } from '../services/DeviceService'
import { Device, DeviceStatus, DeviceType } from '../models/Device'
import { AppConfig } from '../config/AppConfig'
import { AppState } from '../config/AppState'
import { EnvironmentData } from '../models/EnvironmentData'
import { IrrigationCalibration } from '../config/IrrigationCalibration'
import router from '@ohos.router'

/**
 * 智能灌溉页面 - 支持多设备精细控制
 */
@Entry
@Component
struct IrrigationPage {
  @State soilMoisture: number = 0
  @State moistureThreshold: number = 40
  @State isAutoMode: boolean = true
  @State manualDuration: number = 30
  @State irrigationHistory: IrrigationRecord[] = []
  @State isSimulationMode: boolean = false
  @State isIrrigating: boolean = false
  @State remainingTime: number = 0
  @State totalDuration: number = 0
  @State autoWaterAmount: number = 0
  @State autoDuration: number = 0
  @State autoPlanReason: string = ''
  @State currentPointName: string = ''

  // 设备相关状态
  @State pumpList: Device[] = []           // 水泵列表
  @State valveList: Device[] = []          // 水阀列表
  @State selectedPumpIds: string[] = []    // 选中的水泵ID
  @State selectedValveIds: string[] = []   // 选中的水阀ID
  @State showDeviceSelector: boolean = false

  private irrigationService: IrrigationService = new IrrigationService()
  private sensorService: SensorService = new SensorService()
  private deviceService: DeviceService = new DeviceService()
  private appConfig: AppConfig = AppConfig.getInstance()
  private appState: AppState = AppState.getInstance()
  private statusTimer: number = -1

  aboutToAppear() {
    // 检查是否有选中的检测点
    if (!this.appState.currentPoint) {
      router.replaceUrl({ url: 'pages/FieldListPage' })
      return
    }
    
    this.currentPointName = this.appState.currentPoint.pointName
    this.isSimulationMode = this.appConfig.simulationMode
    this.loadData()
    this.loadHistory()
    this.loadDevices()
    
    this.syncIrrigationState()
    
    this.statusTimer = setInterval(() => {
      this.syncIrrigationState()
    }, 1000)

    this.irrigationService.setOnIrrigationComplete(() => {
      this.onIrrigationComplete()
    })
  }

  aboutToDisappear() {
    if (this.statusTimer !== -1) {
      clearInterval(this.statusTimer)
    }
  }

  private syncIrrigationState(): void {
    const wasIrrigating = this.isIrrigating
    const state = IrrigationService.getIrrigationState()
    
    this.isIrrigating = state.isIrrigating
    this.totalDuration = state.duration
    
    if (this.isIrrigating) {
      this.remainingTime = IrrigationService.getRemainingTime()
    } else {
      this.remainingTime = 0
      if (wasIrrigating && !this.isIrrigating) {
        this.loadData()
        this.loadHistory()
        this.loadDevices()
      }
    }
  }

  private async onIrrigationComplete(): Promise<void> {
    console.log('[IrrigationPage] 灌溉完成回调')
    this.isIrrigating = false
    this.remainingTime = 0
    this.totalDuration = 0
    await this.loadData()
    await this.loadHistory()
    await this.loadDevices()
  }

  async loadData() {
    try {
      const pointId = this.appState.currentPoint?.id
      let envData = await this.sensorService.getEnvironmentData(pointId)
      this.soilMoisture = envData.soilMoisture

      let config = this.irrigationService.getConfig()
      this.moistureThreshold = config.moistureThreshold
      this.isAutoMode = config.autoMode
      await this.updateAutoPlan(envData)

      if (this.isAutoMode && !this.isIrrigating) {
        await this.tryAutoIrrigation(envData)
      }
    } catch (error) {
      console.error('加载数据失败:', error)
    }
  }

  async loadHistory() {
    try {
      this.irrigationHistory = await this.irrigationService.getIrrigationHistory()
    } catch (error) {
      console.error('加载历史记录失败:', error)
    }
  }

  async loadDevices() {
    try {
      const pointId = this.appState.currentPoint?.id
      if (!pointId) {
        this.pumpList = []
        this.valveList = []
        return
      }
      
      const allDevices = await this.deviceService.getDeviceList(pointId)
      this.pumpList = allDevices.filter(d => d.deviceType === DeviceType.WATER_PUMP)
      this.valveList = allDevices.filter(d => d.deviceType === DeviceType.VALVE)
      
      // 默认选中第一个设备（如果有）
      if (this.selectedPumpIds.length === 0 && this.pumpList.length > 0) {
        this.selectedPumpIds = [this.pumpList[0].deviceId]
      }
      if (this.selectedValveIds.length === 0 && this.valveList.length > 0) {
        this.selectedValveIds = [this.valveList[0].deviceId]
      }
    } catch (error) {
      console.error('加载设备列表失败:', error)
      this.pumpList = []
      this.valveList = []
    }
  }

  // 切换水泵选择
  private togglePump(deviceId: string): void {
    const index = this.selectedPumpIds.indexOf(deviceId)
    if (index >= 0) {
      this.selectedPumpIds = this.selectedPumpIds.filter(id => id !== deviceId)
    } else {
      this.selectedPumpIds = [...this.selectedPumpIds, deviceId]
    }
  }

  // 切换水阀选择
  private toggleValve(deviceId: string): void {
    const index = this.selectedValveIds.indexOf(deviceId)
    if (index >= 0) {
      this.selectedValveIds = this.selectedValveIds.filter(id => id !== deviceId)
    } else {
      this.selectedValveIds = [...this.selectedValveIds, deviceId]
    }
  }

  async startManualIrrigation() {
    if (this.selectedPumpIds.length === 0) {
      return
    }

    try {
      this.isIrrigating = true
      this.remainingTime = this.manualDuration
      
      // 开启选中的水阀
      for (const valveId of this.selectedValveIds) {
        await this.deviceService.controlDevice(valveId, 'on')
      }
      
      // 开启选中的水泵
      for (const pumpId of this.selectedPumpIds) {
        await this.deviceService.controlDevice(pumpId, 'on')
      }
      
      // 启动灌溉计时
      await this.irrigationService.startIrrigation(1, this.manualDuration, 1)
      console.log('[IrrigationPage] 灌溉已启动')
    } catch (error) {
      console.error('灌溉失败:', error)
    }
  }

  // 停止灌溉
  async stopIrrigation(): Promise<void> {
    // 关闭所有选中的水泵
    for (const pumpId of this.selectedPumpIds) {
      await this.deviceService.controlDevice(pumpId, 'off')
    }
    
    // 关闭所有选中的水阀
    for (const valveId of this.selectedValveIds) {
      await this.deviceService.controlDevice(valveId, 'off')
    }
    
    this.isIrrigating = false
    this.remainingTime = 0
  }

  private async updateAutoPlan(envData: EnvironmentData): Promise<void> {
    const plan = await this.irrigationService.fetchAutoPlan(envData, 1)
    this.autoWaterAmount = plan.waterAmountL
    this.autoDuration = plan.durationSeconds
    this.autoPlanReason = plan.reason
  }

  private async tryAutoIrrigation(envData: EnvironmentData): Promise<void> {
    try {
      const result = await this.irrigationService.startAutoIrrigationByEnvironmentRemote(envData, 1)
      this.autoWaterAmount = result.plan.waterAmountL
      this.autoDuration = result.plan.durationSeconds
      this.autoPlanReason = result.plan.reason

      if (result.started) {
        this.isIrrigating = true
        this.totalDuration = result.plan.durationSeconds
        this.remainingTime = result.plan.durationSeconds
      }
    } catch (error) {
      console.error('自动灌溉执行失败:', error)
    }
  }

  private startAutoIrrigationFromButton(): void {
    this.sensorService.getEnvironmentData()
      .then((envData: EnvironmentData) => {
        return this.updateAutoPlan(envData)
          .then(() => this.tryAutoIrrigation(envData))
      })
      .catch((error: Error) => {
        console.error('自动灌溉执行失败:', error)
      })
  }

  updateConfig() {
    let config = new IrrigationConfig()
    config.autoMode = this.isAutoMode
    config.moistureThreshold = this.moistureThreshold
    config.irrigationDuration = this.manualDuration
    this.irrigationService.updateConfig(config)
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

          Text('智能灌溉')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .margin({ left: 12 })

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

      // 灌溉中提示
      if (this.isIrrigating) {
        Row() {
          Text('💧')
            .fontSize(16)
          Text(` 灌溉中... 剩余 ${this.remainingTime} 秒`)
            .fontSize(13)
            .fontColor('#1976D2')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#E3F2FD')
        .justifyContent(FlexAlign.Center)
      } else if (this.isSimulationMode) {
        Row() {
          Text('🧪')
            .fontSize(16)
          Text(' 模拟模式 - 数据为模拟生成')
            .fontSize(13)
            .fontColor('#F57C00')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor('#FFF3E0')
        .justifyContent(FlexAlign.Center)
      }

      Scroll() {
        Column() {
          this.MoistureSection()
          this.DeviceSelectorSection()
          this.AutoModeSection()
          this.ManualSection()
          this.HistorySection()
        }
        .padding({ left: 16, right: 16, top: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  MoistureSection() {
    Column() {
      Text('当前土壤湿度')
        .fontSize(14)
        .fontColor('#666666')

      Row() {
        Text(this.soilMoisture >= 0 ? this.soilMoisture.toFixed(1) : '-')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getMoistureColor())
        Text('%')
          .fontSize(20)
          .margin({ top: 20 })
          .fontColor('#666666')
      }
      .margin({ top: 16 })

      Progress({
        value: this.soilMoisture >= 0 ? this.soilMoisture : 0,
        total: 100,
        type: ProgressType.Linear
      })
        .width('80%')
        .height(8)
        .margin({ top: 16 })
        .color(this.getMoistureColor())
        .backgroundColor('#E0E0E0')

      Text(this.getMoistureStatus())
        .fontSize(13)
        .fontColor(this.getMoistureColor())
        .margin({ top: 8 })
    }
    .width('100%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  DeviceSelectorSection() {
    Column() {
      Row() {
        Text('设备选择')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Blank()

        Text(`${this.selectedPumpIds.length + this.selectedValveIds.length} 个设备`)
          .fontSize(12)
          .fontColor('#666666')
      }
      .width('100%')

      // 水泵选择
      if (this.pumpList.length > 0) {
        Text('水泵')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
          .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.pumpList, (device: Device) => {
            Row() {
              Checkbox({
                name: device.deviceId,
                group: 'pumps'
              })
                .select(this.selectedPumpIds.indexOf(device.deviceId) >= 0)
                .selectedColor('#4CAF50')
                .onChange((isChecked: boolean) => {
                  this.togglePump(device.deviceId)
                })

              Text(device.deviceName)
                .fontSize(13)
                .fontColor('#333333')
                .margin({ left: 6 })

              // 状态指示
              Circle()
                .width(6)
                .height(6)
                .fill(device.status === DeviceStatus.WORKING ? '#4CAF50' : 
                      device.status === DeviceStatus.ONLINE ? '#2196F3' : '#999999')
                .margin({ left: 6 })
            }
            .height(36)
            .padding({ left: 8, right: 12 })
            .backgroundColor(this.selectedPumpIds.indexOf(device.deviceId) >= 0 ? '#E8F5E9' : '#F5F5F5')
            .borderRadius(18)
            .margin({ right: 8, top: 8 })
          })
        }
      }

      // 水阀选择
      if (this.valveList.length > 0) {
        Text('水阀')
          .fontSize(13)
          .fontColor('#999999')
          .margin({ top: 12 })
          .width('100%')

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.valveList, (device: Device) => {
            Row() {
              Checkbox({
                name: device.deviceId,
                group: 'valves'
              })
                .select(this.selectedValveIds.indexOf(device.deviceId) >= 0)
                .selectedColor('#2196F3')
                .onChange((isChecked: boolean) => {
                  this.toggleValve(device.deviceId)
                })

              Text(device.deviceName)
                .fontSize(13)
                .fontColor('#333333')
                .margin({ left: 6 })

              Circle()
                .width(6)
                .height(6)
                .fill(device.status === DeviceStatus.WORKING ? '#4CAF50' : 
                      device.status === DeviceStatus.ONLINE ? '#2196F3' : '#999999')
                .margin({ left: 6 })
            }
            .height(36)
            .padding({ left: 8, right: 12 })
            .backgroundColor(this.selectedValveIds.indexOf(device.deviceId) >= 0 ? '#E3F2FD' : '#F5F5F5')
            .borderRadius(18)
            .margin({ right: 8, top: 8 })
          })
        }
      }

      // 快捷操作
      Row() {
        Button('全选')
          .fontSize(12)
          .height(28)
          .backgroundColor('#E0E0E0')
          .fontColor('#666666')
          .onClick(() => {
            this.selectedPumpIds = this.pumpList.map(d => d.deviceId)
            this.selectedValveIds = this.valveList.map(d => d.deviceId)
          })

        Button('取消')
          .fontSize(12)
          .height(28)
          .backgroundColor('#E0E0E0')
          .fontColor('#666666')
          .margin({ left: 8 })
          .onClick(() => {
            this.selectedPumpIds = []
            this.selectedValveIds = []
          })
      }
      .width('100%')
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  AutoModeSection() {
    Column() {
      Row() {
        Text('自动灌溉模式')
          .fontSize(16)
          .fontColor('#333333')

        Blank()

        Toggle({
          type: ToggleType.Switch,
          isOn: this.isAutoMode
        })
          .selectedColor('#4CAF50')
          .onChange((isOn: boolean) => {
            this.isAutoMode = isOn
            this.updateConfig()
          })
      }
      .width('100%')

      if (this.isAutoMode) {
        Column() {
          Row() {
            Text('湿度阈值: ' + this.moistureThreshold + '%')
              .fontSize(14)
              .fontColor('#666666')

            Blank()

            Text('低于此值自动灌溉')
              .fontSize(12)
              .fontColor('#999999')
          }
          .width('100%')

          Slider({
            value: this.moistureThreshold,
            min: 20,
            max: 60,
            step: 5
          })
            .width('100%')
            .margin({ top: 12 })
            .blockColor('#4CAF50')
            .trackColor('#E0E0E0')
            .selectedColor('#4CAF50')
            .onChange((value: number) => {
              this.moistureThreshold = Math.round(value)
              this.updateConfig()
            })

          Row() {
            Text('自动计算: 约 ' + this.autoWaterAmount.toFixed(1) + ' 升 / ' + this.autoDuration + ' 秒')
              .fontSize(12)
              .fontColor('#1976D2')
            Blank()
          }
          .width('100%')
          .margin({ top: 12 })

          Text(this.autoPlanReason)
            .fontSize(12)
            .fontColor('#999999')
            .width('100%')
            .margin({ top: 6 })

          Button(this.isIrrigating ? '灌溉中...' : '执行自动灌溉')
            .width('100%')
            .height(40)
            .margin({ top: 12 })
            .backgroundColor(this.isIrrigating ? '#CCCCCC' : '#4CAF50')
            .enabled(!this.isIrrigating && this.autoDuration > 0 && this.selectedPumpIds.length > 0)
            .onClick(() => this.startAutoIrrigationFromButton())
        }
        .width('100%')
        .margin({ top: 16 })
        .padding(16)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  ManualSection() {
    Column() {
      Row() {
        Text('手动灌溉')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        if (this.isSimulationMode) {
          Text(' (模拟)')
            .fontSize(14)
            .fontColor('#FF9800')
        }
      }
      .width('100%')

      if (this.isIrrigating) {
        Column() {
          Row() {
            Text('灌溉进度:')
              .fontSize(14)
              .fontColor('#666666')

            Blank()

            Text(`${this.remainingTime} / ${this.totalDuration} 秒`)
              .fontSize(14)
              .fontColor('#2196F3')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')

          Progress({
            value: this.totalDuration - this.remainingTime,
            total: this.totalDuration,
            type: ProgressType.Linear
          })
            .width('100%')
            .height(8)
            .margin({ top: 12 })
            .color('#2196F3')
            .backgroundColor('#E0E0E0')

          Button('停止灌溉')
            .width('100%')
            .height(40)
            .margin({ top: 12 })
            .backgroundColor('#F44336')
            .onClick(() => this.stopIrrigation())
        }
        .width('100%')
        .margin({ top: 16 })
        .padding(16)
        .backgroundColor('#E3F2FD')
        .borderRadius(8)
      } else {
        Row() {
          Text('灌溉时长:')
            .fontSize(14)
            .fontColor('#666666')

          Text(this.manualDuration + ' 秒')
            .fontSize(14)
            .fontColor('#4CAF50')
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 })

          Blank()

          Text('约 ' + (this.manualDuration * IrrigationCalibration.FLOW_RATE_L_PER_SEC).toFixed(1) + ' 升')
            .fontSize(12)
            .fontColor('#999999')
        }
        .width('100%')
        .margin({ top: 16 })

        Slider({
          value: this.manualDuration,
          min: 10,
          max: 120,
          step: 10
        })
          .width('100%')
          .margin({ top: 8 })
          .blockColor('#2196F3')
          .trackColor('#E0E0E0')
          .selectedColor('#2196F3')
          .onChange((value: number) => {
            this.manualDuration = Math.round(value)
          })

        Button(this.selectedPumpIds.length === 0 ? '请先选择设备' : 
               this.isIrrigating ? `灌溉中 (${this.remainingTime}秒)` : '开始灌溉')
          .width('100%')
          .height(48)
          .margin({ top: 20 })
          .backgroundColor(this.selectedPumpIds.length === 0 ? '#CCCCCC' : '#2196F3')
          .borderRadius(24)
          .enabled(!this.isIrrigating && this.selectedPumpIds.length > 0)
          .onClick(() => this.startManualIrrigation())
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  HistorySection() {
    Column() {
      Text('灌溉历史')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')

      if (this.irrigationHistory.length === 0) {
        Text('暂无灌溉记录')
          .fontSize(14)
          .fontColor('#999999')
          .margin({ top: 16 })
      } else {
        ForEach(this.irrigationHistory.slice(0, 5), (record: IrrigationRecord) => {
          Row() {
            Column() {
              Text(record.mode === IrrigationMode.AUTO ? '自动灌溉' : '手动灌溉')
                .fontSize(14)
                .fontColor('#333333')
              Text(this.formatTime(record.startTime))
                .fontSize(12)
                .fontColor('#999999')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Column() {
              Text(record.waterAmount.toFixed(1) + ' 升')
                .fontSize(14)
                .fontColor('#4CAF50')
              Text(record.duration + ' 秒')
                .fontSize(12)
                .fontColor('#999999')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.End)
          }
          .width('100%')
          .padding(12)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ top: 8 })
        })
      }
    }
    .width('100%')
    .padding(16)
    .margin({ top: 12, bottom: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  private getMoistureColor(): ResourceColor {
    if (this.soilMoisture < 0) return '#999999'
    if (this.soilMoisture < 30) return '#F44336'
    if (this.soilMoisture < 50) return '#FF9800'
    return '#4CAF50'
  }

  private getMoistureStatus(): string {
    if (this.soilMoisture < 0) return '加载数据中...'
    if (this.soilMoisture < 30) return '严重缺水，需要立即灌溉'
    if (this.soilMoisture < 40) return '偏干，建议灌溉'
    if (this.soilMoisture < 60) return '湿度适中'
    return '湿度充足'
  }

  private formatTime(timestamp: string): string {
    if (!timestamp) return '--'
    let date = new Date(timestamp)
    let month = (date.getMonth() + 1).toString().padStart(2, '0')
    let day = date.getDate().toString().padStart(2, '0')
    let hour = date.getHours().toString().padStart(2, '0')
    let minute = date.getMinutes().toString().padStart(2, '0')
    return month + '-' + day + ' ' + hour + ':' + minute
  }
}