import router from '@ohos.router'
import { SensorService } from '../services/SensorService'
import { HistoryDataRecord } from '../models/EnvironmentData'

/**
 * 图表配置
 */
interface ChartConfig {
  key: string
  title: string
  unit: string
  color: string
  icon: string
  minRange: number
  maxRange: number
}

/**
 * 历史数据图表页面
 * 优化：使用Canvas绘制带坐标轴的图表，数据采样提升性能
 */
@Entry
@Component
struct HistoryChartPage {
  @State dataType: string = 'temperature'
  @State historyData: HistoryDataRecord[] = []
  @State isLoading: boolean = true
  @State minValue: number = 0
  @State maxValue: number = 100
  @State avgValue: number = 0
  @State currentValue: number = 0
  @State timeRange: number = 0
  @State showDropdown: boolean = false
  @State chartData: number[] = []  // 预处理后的图表数据
  @State timeLabels: string[] = []  // 时间标签

  private sensorService: SensorService = new SensorService()
  private canvasWidth: number = 320
  private canvasHeight: number = 200

  private chartConfigs: ChartConfig[] = [
    { key: 'temperature', title: '温度', unit: '℃', color: '#F44336', icon: '🌡️', minRange: 0, maxRange: 50 } as ChartConfig,
    { key: 'humidity', title: '湿度', unit: '%', color: '#2196F3', icon: '💧', minRange: 0, maxRange: 100 } as ChartConfig,
    { key: 'light', title: '光照', unit: 'lux', color: '#FF9800', icon: '☀️', minRange: 0, maxRange: 50000 } as ChartConfig,
    { key: 'co2', title: 'CO₂', unit: 'ppm', color: '#9C27B0', icon: '🌬️', minRange: 0, maxRange: 2000 } as ChartConfig,
    { key: 'soilMoisture', title: '土壤湿度', unit: '%', color: '#4CAF50', icon: '🌱', minRange: 0, maxRange: 100 } as ChartConfig
  ]

  async aboutToAppear() {
    const params = router.getParams() as Record<string, string>
    if (params && params['type']) {
      this.dataType = params['type'] as string
    }
    await this.loadData()
  }

  async loadData() {
    this.isLoading = true
    try {
      const limits = [24, 72, 168]
      const limit = limits[this.timeRange]
      
      this.historyData = await this.sensorService.getHistoryData(1, limit)
      this.processChartData()
    } catch (error) {
      console.error('加载历史数据失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  processChartData() {
    if (this.historyData.length === 0) return

    // 提取数值
    const values = this.historyData.map(item => this.getValue(item))
    
    // 计算统计值
    this.currentValue = values[values.length - 1] || 0
    this.minValue = Math.min(...values)
    this.maxValue = Math.max(...values)
    this.avgValue = values.reduce((a, b) => a + b, 0) / values.length

    // 采样数据（最多24个点，减少绘制负担）
    const maxPoints = 24
    const step = Math.max(1, Math.floor(values.length / maxPoints))
    const sampledValues: number[] = []
    const sampledTimes: string[] = []
    
    for (let i = 0; i < values.length; i += step) {
      sampledValues.push(values[i])
      sampledTimes.push(this.formatTime(this.historyData[i].time || this.historyData[i].recordedAt))
    }
    
    // 确保最后一个点包含
    if (sampledValues[sampledValues.length - 1] !== values[values.length - 1]) {
      sampledValues.push(values[values.length - 1])
      sampledTimes.push(this.formatTime(this.historyData[this.historyData.length - 1].time || 
        this.historyData[this.historyData.length - 1].recordedAt))
    }

    this.chartData = sampledValues
    this.timeLabels = sampledTimes
  }

  getValue(item: HistoryDataRecord): number {
    switch (this.dataType) {
      case 'temperature': return item.temperature
      case 'humidity': return item.humidity
      case 'light': return item.light
      case 'co2': return item.co2
      case 'soilMoisture': return item.soilMoisture
      default: return 0
    }
  }

  getConfig(): ChartConfig {
    return this.chartConfigs.find(t => t.key === this.dataType) || this.chartConfigs[0]
  }

  // 切换数据类型（不重新加载）
  switchType(type: string) {
    if (this.dataType !== type) {
      this.dataType = type
      this.showDropdown = false
      this.processChartData()
    } else {
      this.showDropdown = false
    }
  }

  // 切换时间范围（需要重新加载）
  switchTimeRange(index: number) {
    if (this.timeRange !== index) {
      this.timeRange = index
      this.loadData()
    }
  }

  build() {
    Stack() {
      Column() {
        this.TitleSection()
        
        if (this.showDropdown) {
          this.DropdownMenu()
        }

        this.OverviewSection()
        this.TimeRangeSelector()

        if (this.isLoading) {
          this.LoadingSection()
        } else if (this.chartData.length > 0) {
          this.ChartSection()
        } else {
          this.EmptySection()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#f5f5f5')
    }
  }

  @Builder
  TitleSection() {
    Row() {
      Text('<')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .onClick(() => router.back())
        .padding({ left: 12, right: 8, top: 8, bottom: 8 })

      Row() {
        Text(this.getConfig().icon)
          .fontSize(20)
        Text(this.getConfig().title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .margin({ left: 6 })
        Text(this.showDropdown ? '▲' : '▼')
          .fontSize(12)
          .fontColor(Color.White)
          .margin({ left: 6 })
      }
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor('rgba(255,255,255,0.2)')
      .borderRadius(20)
      .onClick(() => this.showDropdown = !this.showDropdown)

      Blank()
    }
    .width('100%')
    .padding({ left: 12, right: 20, top: 12, bottom: 12 })
    .linearGradient({
      angle: 135,
      colors: [[this.getConfig().color, 0], [this.darkenColor(this.getConfig().color), 1]]
    })
  }

  @Builder
  DropdownMenu() {
    Column() {
      ForEach(this.chartConfigs, (item: ChartConfig) => {
        Row() {
          Text(item.icon).fontSize(22)
          Text(item.title)
            .fontSize(16)
            .fontColor(this.dataType === item.key ? item.color : '#333333')
            .margin({ left: 12 })
          Blank()
          if (this.dataType === item.key) {
            Text('✓').fontSize(16).fontColor(item.color)
          }
        }
        .width('100%')
        .height(48)
        .padding({ left: 20, right: 20 })
        .backgroundColor(this.dataType === item.key ? '#F5F5F5' : Color.White)
        .onClick(() => this.switchType(item.key))
        
        if (item.key !== this.chartConfigs[this.chartConfigs.length - 1].key) {
          Divider().color('#E0E0E0')
        }
      })
    }
    .width('100%')
    .backgroundColor(Color.White)
    .shadow({ radius: 8, color: '#1a000000', offsetX: 0, offsetY: 4 })
  }

  @Builder
  OverviewSection() {
    Row() {
      this.StatItem('当前', this.currentValue)
      this.StatItem('平均', this.avgValue)
      this.StatItem('最低', this.minValue)
      this.StatItem('最高', this.maxValue)
    }
    .width('92%')
    .padding(16)
    .margin({ top: 16 })
    .backgroundColor(Color.White)
    .borderRadius(12)
    .justifyContent(FlexAlign.SpaceEvenly)
  }

  @Builder
  StatItem(label: string, value: number) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#999999')
      Row() {
        Text(value.toFixed(1))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.getConfig().color)
        Text(this.getConfig().unit)
          .fontSize(10)
          .fontColor('#999999')
          .margin({ top: 6 })
      }
      .margin({ top: 4 })
    }
  }

  @Builder
  TimeRangeSelector() {
    Row() {
      ForEach(['24小时', '3天', '7天'], (item: string, index: number) => {
        Text(item)
          .fontSize(13)
          .fontColor(this.timeRange === index ? Color.White : '#666666')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.timeRange === index ? this.getConfig().color : '#E0E0E0')
          .borderRadius(16)
          .onClick(() => this.switchTimeRange(index))
      })
    }
    .width('92%')
    .margin({ top: 12 })
    .justifyContent(FlexAlign.SpaceEvenly)
  }

  @Builder
  LoadingSection() {
    Column() {
      LoadingProgress().width(40).height(40).color(this.getConfig().color)
      Text('加载中...').fontSize(14).fontColor('#999999').margin({ top: 12 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  EmptySection() {
    Column() {
      Text('📊').fontSize(48)
      Text('暂无历史数据').fontSize(14).fontColor('#999999').margin({ top: 12 })
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  ChartSection() {
    Column() {
      // 图表容器
      Column() {
        ChartCanvas({
          data: this.chartData,
          timeLabels: this.timeLabels,
          lineColor: this.getConfig().color,
          yMin: this.minValue,
          yMax: this.maxValue,
          unit: this.getConfig().unit
        })
      }
      .width('100%')
      .height(260)
      .backgroundColor(Color.White)
      .borderRadius(12)

      // 数据列表
      this.DataListSection()
    }
    .width('92%')
    .margin({ top: 16 })
    .layoutWeight(1)
  }

  @Builder
  DataListSection() {
    Column() {
      Text('详细数据')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .margin({ top: 16, bottom: 8 })

      List() {
        ForEach(this.historyData.slice().reverse().slice(0, 10), (item: HistoryDataRecord) => {
          ListItem() {
            Row() {
              Text(this.formatDateTime(item.time || item.recordedAt))
                .fontSize(13)
                .fontColor('#666666')
              Blank()
              Text(this.getValue(item).toFixed(1) + ' ' + this.getConfig().unit)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.getConfig().color)
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .border({ width: { bottom: 0.5 }, color: '#E0E0E0' })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .padding(16)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .margin({ top: 12 })
  }

  private formatTime(timestamp: string): string {
    if (!timestamp) return ''
    const date = new Date(timestamp)
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  private formatDateTime(timestamp: string): string {
    if (!timestamp) return ''
    const date = new Date(timestamp)
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  private darkenColor(color: string): string {
    const colorMap: Record<string, string> = {
      '#F44336': '#C62828',
      '#2196F3': '#1565C0',
      '#FF9800': '#E65100',
      '#9C27B0': '#6A1B9A',
      '#4CAF50': '#2E7D32'
    }
    return colorMap[color] || color
  }
}

/**
 * 高性能折线图组件 - 带坐标轴
 */
@Component
struct ChartCanvas {
  @Prop data: number[] = []
  @Prop timeLabels: string[] = []
  @Prop lineColor: string = '#4CAF50'
  @Prop yMin: number = 0
  @Prop yMax: number = 100
  @Prop unit: string = ''

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private hasDrawn: boolean = false

  build() {
    Canvas(this.context)
      .width('100%')
      .height(260)
      .onReady(() => {
        if (!this.hasDrawn) {
          this.drawChart()
          this.hasDrawn = true
        }
      })
  }

  aboutToUpdate() {
    // 数据变化时重绘
    this.hasDrawn = false
  }

  private drawChart() {
    if (this.data.length < 2) return

    const width = 340
    const height = 240
    const leftPad = 45   // 左侧留给Y轴标签
    const rightPad = 15
    const topPad = 20
    const bottomPad = 40  // 底部留给X轴标签

    const chartW = width - leftPad - rightPad
    const chartH = height - topPad - bottomPad

    this.context.clearRect(0, 0, width, height)

    // 计算Y轴范围
    const yRange = this.yMax - this.yMin
    const yStep = yRange / 4

    // ===== 绘制Y轴 =====
    this.context.fillStyle = '#999999'
    this.context.font = '10px sans-serif'
    this.context.textAlign = 'right'
    
    for (let i = 0; i <= 4; i++) {
      const yVal = this.yMax - i * yStep
      const y = topPad + (i / 4) * chartH
      
      // Y轴刻度值
      this.context.fillText(yVal.toFixed(1), leftPad - 8, y + 4)
      
      // 水平网格线
      this.context.strokeStyle = '#E8E8E8'
      this.context.lineWidth = 0.5
      this.context.beginPath()
      this.context.moveTo(leftPad, y)
      this.context.lineTo(width - rightPad, y)
      this.context.stroke()
    }

    // ===== 绘制X轴时间标签 =====
    this.context.textAlign = 'center'
    const labelStep = Math.max(1, Math.floor(this.timeLabels.length / 5))
    
    for (let i = 0; i < this.timeLabels.length; i += labelStep) {
      const x = leftPad + (i / (this.data.length - 1)) * chartW
      const y = height - bottomPad + 15
      
      this.context.fillStyle = '#999999'
      this.context.fillText(this.timeLabels[i] || '', x, y)
    }

    // ===== 绘制折线 =====
    this.context.strokeStyle = this.lineColor
    this.context.lineWidth = 2
    this.context.beginPath()

    const points: number[] = []
    for (let i = 0; i < this.data.length; i++) {
      const x = leftPad + (i / (this.data.length - 1)) * chartW
      const y = topPad + ((this.yMax - this.data[i]) / yRange) * chartH
      points.push(x, y)
      
      if (i === 0) {
        this.context.moveTo(x, y)
      } else {
        this.context.lineTo(x, y)
      }
    }
    this.context.stroke()

    // ===== 绘制填充区域 =====
    const fillColor = this.lineColor.replace('#', '')
    const r = parseInt(fillColor.substring(0, 2), 16)
    const g = parseInt(fillColor.substring(2, 4), 16)
    const b = parseInt(fillColor.substring(4, 6), 16)
    
    this.context.fillStyle = `rgba(${r}, ${g}, ${b}, 0.15)`
    this.context.beginPath()
    this.context.moveTo(leftPad, topPad + chartH)
    
    for (let i = 0; i < this.data.length; i++) {
      const x = leftPad + (i / (this.data.length - 1)) * chartW
      const y = topPad + ((this.yMax - this.data[i]) / yRange) * chartH
      this.context.lineTo(x, y)
    }
    
    this.context.lineTo(leftPad + chartW, topPad + chartH)
    this.context.closePath()
    this.context.fill()

    // ===== 绘制数据点（仅首尾和少量中间点）=====
    this.context.fillStyle = this.lineColor
    const pointIndices = [0, Math.floor(this.data.length / 2), this.data.length - 1]
    
    for (const idx of pointIndices) {
      if (idx < this.data.length) {
        const x = leftPad + (idx / (this.data.length - 1)) * chartW
        const y = topPad + ((this.yMax - this.data[idx]) / yRange) * chartH
        
        this.context.beginPath()
        this.context.arc(x, y, 4, 0, 2 * Math.PI)
        this.context.fill()
      }
    }

    // ===== 高亮最后一个点 =====
    const lastIdx = this.data.length - 1
    const lastX = leftPad + chartW
    const lastY = topPad + ((this.yMax - this.data[lastIdx]) / yRange) * chartH
    
    this.context.fillStyle = '#FFFFFF'
    this.context.beginPath()
    this.context.arc(lastX, lastY, 6, 0, 2 * Math.PI)
    this.context.fill()
    
    this.context.fillStyle = this.lineColor
    this.context.beginPath()
    this.context.arc(lastX, lastY, 4, 0, 2 * Math.PI)
    this.context.fill()

    // ===== 绘制单位标签 =====
    this.context.fillStyle = '#666666'
    this.context.font = '11px sans-serif'
    this.context.textAlign = 'left'
    this.context.fillText(this.unit, 5, topPad + 10)
  }
}
