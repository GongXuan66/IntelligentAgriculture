import router from '@ohos.router'
import { Field, FieldTypeNames, MonitorPoint } from '../models/Field'
import { EnvironmentData } from '../models/EnvironmentData'
import { FieldService } from '../services/FieldService'
import { SensorService } from '../services/SensorService'
import { DeviceService } from '../services/DeviceService'
import { AlarmService } from '../services/AlarmService'
import { WeatherService } from '../services/WeatherService'
import { WeatherData, WeatherForecast, getWeatherIcon } from '../models/WeatherData'
import { AppConfig } from '../config/AppConfig'
import { AppState } from '../config/AppState'
import { NavBottom } from '../components/NavBottom'
import { Device, DeviceStatus } from '../models/Device'

class FieldWithEnv {
  id: number = 0
  fieldId: string = ''
  fieldName: string = ''
  fieldType: string = 'outdoor'
  location: string = ''
  area: number = 0
  cropType: string = ''
  status: number = 1
  envData: EnvironmentData | null = null
  pointCount: number = 0
  deviceCount: number = 0
  alarmCount: number = 0
}

/**
 * 首页 - 农田页面
 * 地块总览和快捷操作入口
 */
@Entry
@Component
struct Index {
  @State fields: FieldWithEnv[] = []
  @State isLoading: boolean = true
  @State isSimulationMode: boolean = false
  @State totalFields: number = 0
  @State totalPoints: number = 0
  @State totalAlarms: number = 0
  @State totalDevices: number = 0
  @State weather: WeatherData | null = null
  @State weatherError: string = ''
  @State weatherLoading: boolean = true
  
  private fieldService: FieldService = new FieldService()
  private sensorService: SensorService = new SensorService()
  private deviceService: DeviceService = new DeviceService()
  private alarmService: AlarmService = AlarmService.getInstance()
  private weatherService: WeatherService = WeatherService.getInstance()
  private appState: AppState = AppState.getInstance()
  private appConfig: AppConfig = AppConfig.getInstance()
  private refreshInterval: number = -1

  async aboutToAppear() {
    this.isSimulationMode = this.appConfig.simulationMode
    await this.loadFields()
    await this.loadWeather()
    
    // 定时刷新
    this.refreshInterval = setInterval(() => {
      this.loadFields()
    }, 10000)
  }

  aboutToDisappear() {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval)
    }
  }

  async loadFields() {
    try {
      const fieldList = await this.fieldService.getFieldList(true)
      
      // 获取统计
      const devices = await this.deviceService.getDeviceList()
      this.totalDevices = devices.length
      this.totalAlarms = await this.alarmService.getUnprocessedCount()
      
      // 获取每个地块的最新环境数据
      const fieldsWithEnv: FieldWithEnv[] = []
      let totalPoints = 0
      
      for (const field of fieldList) {
        const detail = await this.fieldService.getFieldDetail(field.id!)
        const points = detail?.points || []
        totalPoints += points.length
        
        // 获取第一个检测点的环境数据作为参考
        let envData: EnvironmentData | null = null
        if (points.length > 0) {
          envData = await this.sensorService.getEnvironmentData(points[0].id!)
        }
        
        const fieldWithEnv = new FieldWithEnv()
        fieldWithEnv.id = field.id!
        fieldWithEnv.fieldId = field.fieldId || ''
        fieldWithEnv.fieldName = field.fieldName || ''
        fieldWithEnv.fieldType = field.fieldType || 'outdoor'
        fieldWithEnv.location = field.location || ''
        fieldWithEnv.area = field.area || 0
        fieldWithEnv.cropType = field.cropType || ''
        fieldWithEnv.status = field.status || 1
        fieldWithEnv.envData = envData
        fieldWithEnv.pointCount = points.length
        fieldWithEnv.deviceCount = 0
        fieldWithEnv.alarmCount = 0
        
        fieldsWithEnv.push(fieldWithEnv)
      }
      
      this.fields = fieldsWithEnv
      this.totalFields = fieldList.length
      this.totalPoints = totalPoints
    } catch (error) {
      console.error('加载地块列表失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  async loadWeather() {
    this.weatherLoading = true
    this.weatherError = ''
    try {
      this.weather = await this.weatherService.getCurrentWeather()
      if (!this.weather) {
        this.weatherError = this.weatherService.getLastError() || '获取天气失败'
      }
    } catch (error) {
      console.error('加载天气失败:', error)
      this.weatherError = '网络连接失败'
    } finally {
      this.weatherLoading = false
    }
  }

  build() {
    Column() {
      // 顶部标题栏
      Column() {
        Row() {
          Text('智慧农业')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          
          Blank()
          
          Row() {
            Text(this.isSimulationMode ? '模拟' : '在线')
              .fontSize(12)
              .fontColor(this.isSimulationMode ? '#FF9800' : '#FFFFFF')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.isSimulationMode ? 'rgba(255,152,0,0.3)' : 'rgba(255,255,255,0.2)')
          .borderRadius(12)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 16 })
      .linearGradient({
        angle: 135,
        colors: [['#4CAF50', 0], ['#2E7D32', 1]]
      })

      // 天气卡片
      Column() {
        if (this.weatherLoading) {
          // 加载中
          Row() {
            LoadingProgress()
              .width(20)
              .height(20)
              .color('#666666')
            Text(' 获取天气中...')
              .fontSize(14)
              .fontColor('#666666')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding(16)
        } else if (this.weather) {
          this.WeatherCard()
        } else {
          // 离线或错误状态
          Row() {
            Text('⚠️')
              .fontSize(16)
            Text(this.weatherError || '无法获取天气')
              .fontSize(14)
              .fontColor('#999999')
              .margin({ left: 8 })
            Blank()
            Text('重试')
              .fontSize(14)
              .fontColor('#4CAF50')
              .onClick(() => {
                this.weatherService.clearCache()
                this.loadWeather()
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor(Color.White)
          .borderRadius(16)
          .margin({ left: 16, right: 16, top: 12 })
        }
      }

      // 主内容区域
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
            // 今日概览
            this.OverviewSection()

            // 地块列表
            this.FieldListSection()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }

      // 底部导航
      NavBottom({ currentIndex: 0 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  OverviewSection() {
    Column() {
      Text('📊 今日概览')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')

      Row() {
        this.OverviewItem('🌾', '地块', this.totalFields, '#4CAF50')
        this.OverviewItem('📍', '检测点', this.totalPoints, '#2196F3')
        this.OverviewItem('🔔', '报警', this.totalAlarms, '#F44336')
        this.OverviewItem('🔧', '设备', this.totalDevices, '#FF9800')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  OverviewItem(icon: string, label: string, value: number, color: ResourceColor) {
    Column() {
      Text(icon)
        .fontSize(24)

      Text(value.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 4 })

      Text(label)
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 2 })
    }
    .width('25%')
  }

  @Builder
  FieldListSection() {
    Column() {
      Text('🌾 我的地块')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')

      if (this.fields.length === 0) {
        Column() {
          Text('🌱')
            .fontSize(48)
          Text('暂无地块数据')
            .fontSize(16)
            .fontColor('#999999')
            .margin({ top: 12 })
          Text('请在管理后台添加地块')
            .fontSize(14)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .width('100%')
        .padding(40)
      } else {
        ForEach(this.fields, (field: FieldWithEnv) => {
          this.FieldCard(field)
        })
      }
    }
    .width('100%')
    .margin({ top: 16 })
  }

  @Builder
  FieldCard(field: FieldWithEnv) {
    Column() {
      // 卡片头部
      Row() {
        // 地块图标
        Text(this.getFieldIcon(field.fieldType))
          .fontSize(32)

        Column() {
          Text(field.fieldName)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Row() {
            Text(FieldTypeNames[field.fieldType] || '户外田地')
              .fontSize(12)
              .fontColor('#999999')

            if (field.area > 0) {
              Text(` · ${field.area}亩`)
                .fontSize(12)
                .fontColor('#999999')
            }
          }
          .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 12 })

        Blank()

        // 状态指示
        this.StatusBadge(field)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 8 })

      // 作物信息
      if (field.cropType) {
        Row() {
          Text('🌾')
            .fontSize(14)
          Text(`种植: ${field.cropType}`)
            .fontSize(13)
            .fontColor('#666666')
            .margin({ left: 4 })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      // 环境数据概览
      if (field.envData) {
        this.EnvDataSection(field.envData)
      }

      // 检测点信息和进入按钮
      Row() {
        Row() {
          Text('📍')
            .fontSize(12)
          Text(`${field.pointCount} 个检测点`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ left: 4 })
        }

        Blank()

        // 进入按钮
        Row() {
          Text('进入')
            .fontSize(14)
            .fontColor('#4CAF50')
          Text(' >')
            .fontSize(14)
            .fontColor('#4CAF50')
        }
        .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        .backgroundColor('#E8F5E9')
        .borderRadius(16)
        .onClick(() => this.navigateToFieldDetail(field))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin({ top: 12 })
  }

  @Builder
  WeatherCard() {
    Column() {
      // 主天气信息
      Row() {
        // 天气图标和温度
        Column() {
          Text(getWeatherIcon(this.weather!.icon))
            .fontSize(48)
          
          Text(this.weather!.text)
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        
        Column() {
          Text(`${this.weather!.temp}°`)
            .fontSize(42)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
          
          Text(`体感 ${this.weather!.feelsLike}°C`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
        
        Blank()
        
        // 详细信息
        Column() {
          Row() {
            Text('💧')
              .fontSize(12)
            Text(`${this.weather!.humidity}%`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ left: 2 })
          }
          
          Row() {
            Text('💨')
              .fontSize(12)
            Text(`${this.weather!.windDir} ${this.weather!.windSpeed}km/h`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ left: 2 })
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(16)
      
      // 未来天气预报
      if (this.weather!.forecast && this.weather!.forecast.length > 0) {
        Row() {
          ForEach(this.weather!.forecast, (day: WeatherForecast) => {
            Column() {
              Text(day.date)
                .fontSize(12)
                .fontColor('#999999')
              
              Text(getWeatherIcon(day.iconDay))
                .fontSize(24)
                .margin({ top: 4 })
              
              Text(`${day.tempMax}°/${day.tempMin}°`)
                .fontSize(11)
                .fontColor('#666666')
                .margin({ top: 4 })
            }
            .layoutWeight(1)
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 12 })
        .backgroundColor('#F9F9F9')
        .margin({ left: 16, right: 16, bottom: 12 })
        .borderRadius(8)
      }
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(16)
    .margin({ left: 16, right: 16, top: 12 })
    .shadow({ radius: 4, color: '#10000000', offsetX: 0, offsetY: 2 })
  }

  @Builder
  StatusBadge(field: FieldWithEnv) {
    Row() {
      Circle()
        .width(6)
        .height(6)
        .fill(this.getStatusColor(field))
        .margin({ right: 4 })

      Text(this.getStatusText(field))
        .fontSize(12)
        .fontColor(this.getStatusColor(field))
    }
    .padding({ left: 8, right: 8, top: 4, bottom: 4 })
    .backgroundColor(this.getStatusColor(field) + '20')
    .borderRadius(12)
  }

  private getStatusText(field: FieldWithEnv): string {
    if (field.envData) {
      if (field.envData.temperature > 35 || field.envData.temperature < 10) {
        return '异常'
      } else if (field.envData.soilMoisture < 30) {
        return '需灌溉'
      }
    }
    return '正常'
  }

  private getStatusColor(field: FieldWithEnv): ResourceColor {
    if (field.envData) {
      if (field.envData.temperature > 35 || field.envData.temperature < 10) {
        return '#F44336'
      } else if (field.envData.soilMoisture < 30) {
        return '#FF9800'
      }
    }
    return '#4CAF50'
  }

  @Builder
  EnvDataSection(envData: EnvironmentData) {
    Row() {
      this.EnvItem('🌡️', this.formatValue(envData.temperature, 1) + '℃', this.getTempColor(envData.temperature))
      this.EnvItem('💧', this.formatValue(envData.humidity, 0) + '%', this.getHumidityColor(envData.humidity))
      this.EnvItem('☀️', this.formatValue(envData.light, 0) + 'lux', this.getLightColor(envData.light))
      this.EnvItem('🌱', this.formatValue(envData.soilMoisture, 0) + '%', this.getSoilColor(envData.soilMoisture))
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({ left: 8, right: 8, top: 8, bottom: 8 })
    .backgroundColor('#F9F9F9')
    .margin({ left: 16, right: 16, top: 8 })
    .borderRadius(8)
  }

  @Builder
  EnvItem(icon: string, value: string, color: ResourceColor) {
    Column() {
      Text(icon)
        .fontSize(16)

      Text(value)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(color)
        .margin({ top: 2 })
    }
    .width('25%')
  }

  // 导航到地块详情页
  private navigateToFieldDetail(field: FieldWithEnv) {
    // 保存到全局状态
    this.appState.setCurrentField({
      id: field.id,
      fieldId: field.fieldId,
      fieldName: field.fieldName,
      fieldType: field.fieldType,
      location: field.location,
      area: field.area,
      cropType: field.cropType,
      status: field.status
    })

    router.pushUrl({
      url: 'pages/FieldDetailPage',
      params: {
        fieldId: field.id,
        fieldName: field.fieldName
      }
    }).catch((error: Error) => {
      console.error('页面跳转失败:', error)
    })
  }

  private getFieldIcon(type: string): string {
    switch (type) {
      case 'greenhouse':
        return '🏠'
      case 'orchard':
        return '🌳'
      case 'outdoor':
        return '🌾'
      default:
        return '🌱'
    }
  }

  private formatValue(value: number, decimals: number): string {
    if (value < 0) return '-'
    return value.toFixed(decimals)
  }

  private getTempColor(temp: number): ResourceColor {
    if (temp < 0) return '#999999'
    if (temp > 35) return '#F44336'
    if (temp < 10) return '#2196F3'
    return '#333333'
  }

  private getHumidityColor(humidity: number): ResourceColor {
    if (humidity < 0) return '#999999'
    if (humidity > 80) return '#FF9800'
    if (humidity < 30) return '#F44336'
    return '#333333'
  }

  private getLightColor(light: number): ResourceColor {
    if (light < 0) return '#999999'
    if (light < 300) return '#FF9800'
    return '#333333'
  }

  private getSoilColor(soil: number): ResourceColor {
    if (soil < 0) return '#999999'
    if (soil < 30) return '#F44336'
    if (soil < 40) return '#FF9800'
    return '#333333'
  }
}