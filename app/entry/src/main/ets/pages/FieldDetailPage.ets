import router from '@ohos.router'
import { EnvironmentData } from '../models/EnvironmentData'
import { Field, MonitorPoint } from '../models/Field'
import { SensorService } from '../services/SensorService'
import { AlarmService } from '../services/AlarmService'
import { IrrigationService } from '../services/IrrigationService'
import { DeviceService } from '../services/DeviceService'
import { FieldService } from '../services/FieldService'
import { AppState } from '../config/AppState'
import { DeviceStatus } from '../models/Device'
import { AppConfig } from '../config/AppConfig'
import { DataCard } from '../components/DataCard'

/**
 * 地块详情页 - 环境监测
 * 从首页点击地块卡片进入
 */
@Entry
@Component
struct FieldDetailPage {
  @State envData: EnvironmentData = new EnvironmentData()
  @State isLoading: boolean = true
  @State lastUpdate: string = '--'
  @State isSimulationMode: boolean = false
  @State deviceCount: number = 0
  @State onlineCount: number = 0
  @State workingCount: number = 0
  
  // 当前地块和检测点
  @State currentField: Field | null = null
  @State currentPoint: MonitorPoint | null = null
  @State points: MonitorPoint[] = []
  @State showPointPicker: boolean = false
  
  // 路由参数
  private fieldId: number = 0
  private fieldName: string = ''
  
  private sensorService: SensorService = new SensorService()
  private alarmService: AlarmService = AlarmService.getInstance()
  private irrigationService: IrrigationService = new IrrigationService()
  private deviceService: DeviceService = new DeviceService()
  private fieldService: FieldService = new FieldService()
  private appState: AppState = AppState.getInstance()
  private appConfig: AppConfig = AppConfig.getInstance()
  private refreshInterval: number = -1

  async aboutToAppear() {
    // 获取路由参数
    const params = router.getParams() as Record<string, Object>
    if (params) {
      this.fieldId = params['fieldId'] as number || 0
      this.fieldName = params['fieldName'] as string || ''
    }
    
    // 如果没有参数，尝试从全局状态获取
    if (!this.fieldId && this.appState.currentField) {
      this.currentField = this.appState.currentField
      this.fieldId = this.currentField.id!
    }
    
    await this.loadLocalConfig()
    this.isSimulationMode = this.appConfig.simulationMode
    await this.loadFieldData()
    this.loadData()
    this.refreshInterval = setInterval(() => {
      this.loadData()
    }, 5000)
  }
  
  /**
   * 加载地块数据
   */
  async loadFieldData() {
    if (this.fieldId) {
      // 从后端获取地块详情
      const detail = await this.fieldService.getFieldDetail(this.fieldId)
      if (detail) {
        this.currentField = detail.field
        this.points = detail.points || []
        
        if (this.points.length > 0) {
          this.currentPoint = this.points[0]
          this.appState.setCurrentPoint(this.points[0])
        }
      }
    }
  }

  private async loadLocalConfig(): Promise<void> {
    try {
      await this.alarmService.loadConfigFromStorage()
      await this.irrigationService.loadConfigFromStorage()
      console.log('[FieldDetailPage] 本地配置加载完成')
    } catch (error) {
      console.error('[FieldDetailPage] 加载本地配置失败:', error)
    }
  }

  aboutToDisappear() {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval)
    }
  }

  async loadData() {
    await Promise.all([
      this.loadEnvironmentData(),
      this.loadDeviceData()
    ])
  }

  async loadDeviceData() {
    try {
      const pointId = this.currentPoint?.id || this.appState.currentPointId
      const devices = await this.deviceService.getDeviceList(pointId)
      this.deviceCount = devices.length
      this.onlineCount = devices.filter(d => d.status === DeviceStatus.ONLINE).length
      this.workingCount = devices.filter(d => d.status === DeviceStatus.WORKING).length
    } catch (error) {
      console.error('获取设备数据失败:', error)
    }
  }

  async loadEnvironmentData() {
    try {
      const pointId = this.currentPoint?.id || this.appState.currentPointId
      this.envData = await this.sensorService.getEnvironmentData(pointId)
      
      if (this.isSimulationMode) {
        this.lastUpdate = '模拟'
      }

      const connected = this.envData.isConnected ?? true
      if (connected) {
        if (!this.isSimulationMode) {
          this.lastUpdate = this.formatTime(this.envData.timestamp)
        }
      } else {
        this.lastUpdate = '离线'
      }
    } catch (error) {
      console.error('获取环境数据失败:', error)
      this.lastUpdate = '离线'
    } finally {
      this.isLoading = false
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      this.TitleSection()

      // 模拟模式提示
      if (this.isSimulationMode) {
        this.SimulationBanner()
      } else if (this.envData.isConnected === false) {
        this.OfflineBanner()
      }

      // 主内容区域
      if (this.isLoading) {
        this.LoadingSection()
      } else {
        this.ContentSection()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  TitleSection() {
    Column() {
      // 顶部标题行
      Row() {
        // 返回按钮
        Row() {
          Text('←')
            .fontSize(20)
            .fontColor(Color.White)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(255,255,255,0.2)')
        .borderRadius(18)
        .onClick(() => {
          router.back()
        })
        
        // 地块名称
        Column() {
          Text(this.currentField?.fieldName || this.fieldName || '地块详情')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          
          if (this.currentField?.cropType) {
            Text(`🌾 ${this.currentField.cropType}`)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.8)')
              .margin({ top: 2 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })
        .layoutWeight(1)
        
        Blank()

        Row() {
          Text(this.isSimulationMode ? '模拟' : '在线')
            .fontSize(12)
            .fontColor(this.isSimulationMode ? '#FF9800' : '#FFFFFF')
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor(this.isSimulationMode ? 'rgba(255,152,0,0.3)' : 'rgba(255,255,255,0.2)')
        .borderRadius(4)
        .margin({ right: 8 })
        
        Text(this.lastUpdate)
          .fontSize(12)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .width('100%')
      
      // 检测点选择器
      if (this.points.length > 1) {
        this.PointSelectorRow()
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .linearGradient({
      angle: 135,
      colors: [['#4CAF50', 0], ['#2E7D32', 1]]
    })
  }
  
  @Builder
  PointSelectorRow() {
    Row() {
      Text('📍')
        .fontSize(14)
      Text(this.currentPoint?.pointName || '选择区域')
        .fontSize(14)
        .fontColor(Color.White)
        .margin({ left: 6 })
      Text('▼')
        .fontSize(10)
        .fontColor('rgba(255,255,255,0.7)')
        .margin({ left: 4 })
    }
    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
    .backgroundColor('rgba(255,255,255,0.2)')
    .borderRadius(16)
    .margin({ top: 10 })
    .onClick(() => {
      this.showPointPicker = true
    })
    .bindMenu(this.showPointPicker, this.PointMenu())
  }
  
  @Builder
  PointMenu() {
    Menu() {
      ForEach(this.points, (point: MonitorPoint) => {
        MenuItem({ content: point.pointName })
          .selected(this.currentPoint?.id === point.id)
          .onClick(() => {
            this.currentPoint = point
            this.appState.setCurrentPoint(point)
            this.showPointPicker = false
            this.loadData()
          })
      })
    }
  }

  @Builder
  SimulationBanner() {
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

  @Builder
  OfflineBanner() {
    Row() {
      Text('⚠️')
        .fontSize(16)
      Text(' 服务器连接失败，请检查网络配置')
        .fontSize(13)
        .fontColor('#D32F2F')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor('#FFEBEE')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  LoadingSection() {
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
  }

  @Builder
  ContentSection() {
    Scroll() {
      Column() {
        // 设备总数卡片
        this.DeviceCountCard()

        // 环境数据卡片区域
        Column() {
          Row() {
            DataCard({
              title: '温度',
              value: this.formatValue(this.envData.temperature, 1),
              unit: '℃',
              iconText: '🌡️',
              statusColor: this.getTemperatureColor(),
              onCardClick: () => this.navigateToChart('temperature')
            })

            DataCard({
              title: '湿度',
              value: this.formatValue(this.envData.humidity, 1),
              unit: '%',
              iconText: '💧',
              statusColor: this.getHumidityColor(),
              onCardClick: () => this.navigateToChart('humidity')
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceEvenly)

          Row() {
            DataCard({
              title: '光照',
              value: this.formatValue(this.envData.light, 0),
              unit: 'lux',
              iconText: '☀️',
              statusColor: this.getLightColor(),
              onCardClick: () => this.navigateToChart('light')
            })

            DataCard({
              title: 'CO₂',
              value: this.formatValue(this.envData.co2, 0),
              unit: 'ppm',
              iconText: '🌬️',
              statusColor: this.getCo2Color(),
              onCardClick: () => this.navigateToChart('co2')
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceEvenly)
          .margin({ top: 12 })

          Row() {
            DataCard({
              title: '土壤湿度',
              value: this.formatValue(this.envData.soilMoisture, 1),
              unit: '%',
              iconText: '🌱',
              cardWidth: '92%',
              statusColor: this.getSoilMoistureColor(),
              onCardClick: () => this.navigateToChart('soilMoisture')
            })
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ top: 12 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 20 })

        // 状态概览
        this.StatusOverview()

        // 快捷操作入口
        this.QuickActionsSection()

        // 刷新按钮
        Button('刷新数据')
          .width('80%')
          .height(44)
          .margin({ top: 24, bottom: 20 })
          .backgroundColor('#4CAF50')
          .borderRadius(22)
          .onClick(() => this.loadData())
      }
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  QuickActionsSection() {
    Column() {
      Text('⚡ 快捷操作')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 12 })

      Row() {
        this.ActionButton('💧 灌溉', '#2196F3', 'pages/IrrigationPage')
        this.ActionButton('☀️ 补光', '#FF9800', 'pages/LightPage')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)

      Row() {
        this.ActionButton('🌬️ 通风', '#03A9F4', 'pages/VentilationPage')
        this.ActionButton('🔔 报警', '#F44336', 'pages/AlarmPage')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 12 })
    }
    .width('92%')
    .padding(16)
    .margin({ top: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  ActionButton(title: string, color: ResourceColor, page: string) {
    Column() {
      Text(title.split(' ')[0])
        .fontSize(28)

      Text(title.split(' ')[1] || '')
        .fontSize(14)
        .fontColor('#333333')
        .margin({ top: 6 })
    }
    .width('45%')
    .height(80)
    .backgroundColor(color + '15')
    .borderRadius(12)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      router.pushUrl({ url: page })
    })
  }

  @Builder
  DeviceCountCard() {
    Column() {
      Row() {
        Text(this.deviceCount.toString())
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor('#2E7D32')
        
        Text(' 台设备')
          .fontSize(16)
          .fontColor('#666666')
          .margin({ top: 20 })
        
        Blank()
        
        // 状态分布
        Row() {
          this.StatusChip('在线', this.onlineCount, '#4CAF50')
          this.StatusChip('工作中', this.workingCount, '#FF9800')
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
    }
    .width('92%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ top: 16 })
  }

  @Builder
  StatusChip(label: string, count: number, color: ResourceColor) {
    Row() {
      Circle()
        .width(6)
        .height(6)
        .fill(color)
        .margin({ right: 4 })
      
      Text(`${label} ${count}`)
        .fontSize(12)
        .fontColor('#666666')
    }
    .margin({ left: 12 })
  }

  @Builder
  StatusOverview() {
    Column() {
      Text('状态概览')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ bottom: 12 })

      Row() {
        this.StatusItem('温度', this.isTemperatureNormal())
        this.StatusItem('湿度', this.isHumidityNormal())
        this.StatusItem('光照', this.isLightNormal())
        this.StatusItem('CO₂', this.isCo2Normal())
        this.StatusItem('土壤', this.isSoilMoistureNormal())
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
    }
    .width('92%')
    .padding(16)
    .margin({ top: 20 })
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  @Builder
  StatusItem(title: string, isNormal: boolean) {
    Column() {
      Text(isNormal ? '✅' : '⚠️')
        .fontSize(20)
      
      Text(title)
        .fontSize(11)
        .fontColor('#666666')
        .margin({ top: 4 })
    }
  }

  // 状态判断方法
  private isTemperatureNormal(): boolean {
    if (this.envData.temperature < 0) return false
    return this.envData.temperature >= 10 && this.envData.temperature <= 35
  }

  private isHumidityNormal(): boolean {
    if (this.envData.humidity < 0) return false
    return this.envData.humidity >= 30 && this.envData.humidity <= 80
  }

  private isLightNormal(): boolean {
    if (this.envData.light < 0) return false
    return this.envData.light >= 300
  }

  private isCo2Normal(): boolean {
    if (this.envData.co2 < 0) return false
    return this.envData.co2 <= 1000
  }

  private isSoilMoistureNormal(): boolean {
    if (this.envData.soilMoisture < 0) return false
    return this.envData.soilMoisture >= 40
  }

  // 跳转到历史数据图表页面
  private navigateToChart(dataType: string): void {
    router.pushUrl({
      url: 'pages/HistoryChartPage',
      params: { type: dataType }
    }).catch((error: Error) => {
      console.error('页面跳转失败:', error)
    })
  }

  private formatValue(value: number, decimals: number): string {
    if (value < 0) {
      return '-'
    }
    return value.toFixed(decimals)
  }

  private getTemperatureColor(): ResourceColor {
    if (this.envData.temperature < 0) return '#999999'
    if (this.envData.temperature > 35) return '#F44336'
    if (this.envData.temperature < 10) return '#2196F3'
    return '#4CAF50'
  }

  private getHumidityColor(): ResourceColor {
    if (this.envData.humidity < 0) return '#999999'
    if (this.envData.humidity > 80) return '#FF9800'
    if (this.envData.humidity < 30) return '#F44336'
    return '#4CAF50'
  }

  private getLightColor(): ResourceColor {
    if (this.envData.light < 0) return '#999999'
    if (this.envData.light < 300) return '#FF9800'
    return '#4CAF50'
  }

  private getCo2Color(): ResourceColor {
    if (this.envData.co2 < 0) return '#999999'
    if (this.envData.co2 > 1000) return '#F44336'
    return '#4CAF50'
  }

  private getSoilMoistureColor(): ResourceColor {
    if (this.envData.soilMoisture < 0) return '#999999'
    if (this.envData.soilMoisture < 30) return '#F44336'
    if (this.envData.soilMoisture < 40) return '#FF9800'
    return '#4CAF50'
  }

  private formatTime(timestamp: string): string {
    if (!timestamp) return '--'
    let date = new Date(timestamp)
    let hour = date.getHours().toString().padStart(2, '0')
    let minute = date.getMinutes().toString().padStart(2, '0')
    let second = date.getSeconds().toString().padStart(2, '0')
    return `${hour}:${minute}:${second}`
  }
}
