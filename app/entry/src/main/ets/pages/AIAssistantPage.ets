import { NavBottom } from '../components/NavBottom'
import { HttpClient } from '../web/HttpClient'
import { AppConfig } from '../config/AppConfig'
import { AppState } from '../config/AppState'
import { EnvironmentData } from '../models/EnvironmentData'
import { SensorService } from '../services/SensorService'

interface ChatMessage {
  role: string  // 'user' or 'assistant'
  content: string
  time: string
}

interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

interface ChatResponse {
  reply: string
  sessionId: string
}

interface ChatRequest {
  sessionId: string
  message: string
  context: string
}

/**
 * AI助手页面
 */
@Entry
@Component
struct AIAssistantPage {
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State isLoading: boolean = false
  @State sessionId: string = ''
  @State isSimulationMode: boolean = false
  @State currentEnvData: EnvironmentData | null = null
  
  private readonly sensorService: SensorService = new SensorService()
  private readonly appState: AppState = AppState.getInstance()
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private scrollController: Scroller = new Scroller()

  async aboutToAppear() {
    this.isSimulationMode = this.appConfig.simulationMode
    this.sessionId = this.generateSessionId()
    
    // 加载当前环境数据
    const pointId = this.appState.currentPoint?.id
    if (pointId) {
      this.currentEnvData = await this.sensorService.getEnvironmentData(pointId)
    }
    
    // 添加欢迎消息
    this.addMessage('assistant', '您好！我是农业AI助手，可以帮您：\n\n📊 分析作物生长状况\n🌾 诊断病虫害问题\n💧 提供灌溉建议\n🌡️ 监控环境数据\n\n请问有什么可以帮助您的？')
  }

  private generateSessionId(): string {
    return 'session_' + Date.now() + '_' + Math.random().toString(36).substring(2, 9)
  }

  private addMessage(role: string, content: string): void {
    let msg: ChatMessage = {
      role: role,
      content: content,
      time: this.formatTime(new Date().toISOString())
    }
    this.messages = [...this.messages, msg]
    
    // 滚动到底部
    setTimeout(() => {
      this.scrollController.scrollEdge(Edge.Bottom)
    }, 100)
  }

  async sendMessage(): Promise<void> {
    if (!this.inputText.trim() || this.isLoading) {
      return
    }

    let userMessage = this.inputText.trim()
    this.inputText = ''
    this.addMessage('user', userMessage)
    this.isLoading = true

    try {
      // 构建上下文
      let context = ''
      if (this.currentEnvData) {
        context = `当前环境数据：温度${this.currentEnvData.temperature}℃，湿度${this.currentEnvData.humidity}%，光照${this.currentEnvData.light}lux，土壤湿度${this.currentEnvData.soilMoisture}%。`
      }

      let request: ChatRequest = {
        sessionId: this.sessionId,
        message: userMessage,
        context: context
      }
      let result = await HttpClient.post<ApiResponse<ChatResponse>>('/api/ai/chat', request)

      if (result.code === 200 && result.data) {
        this.addMessage('assistant', result.data.reply)
      } else {
        this.addMessage('assistant', '抱歉，我暂时无法回答这个问题。请稍后再试。')
      }
    } catch (error) {
      console.error('AI对话失败:', error)
      // 模拟响应
      this.addMessage('assistant', this.getMockResponse(userMessage))
    } finally {
      this.isLoading = false
    }
  }

  private getMockResponse(message: string): string {
    if (message.includes('温度') || message.includes('高温')) {
      return '根据当前环境数据，建议您：\n\n1️⃣ 如果温度超过35℃，建议开启通风设备\n2️⃣ 适当增加灌溉频率，降低土壤温度\n3️⃣ 对于大棚作物，可打开遮阳网\n\n需要我帮您开启通风设备吗？'
    }
    if (message.includes('灌溉') || message.includes('浇水') || message.includes('水')) {
      return '根据土壤湿度数据分析：\n\n💧 当前土壤湿度较低，建议灌溉\n📐 预计用水量：15-20升\n⏱️ 建议时长：30-40秒\n\n您可以在农田页面开启灌溉系统。'
    }
    if (message.includes('光照') || message.includes('补光')) {
      return '光照条件分析：\n\n☀️ 当前光照充足，无需补光\n🌅 如遇阴雨天气，建议开启补光灯\💡 补光灯亮度建议设置为60-80%\n\n需要调整光照设置吗？'
    }
    return '我已收到您的问题。作为农业AI助手，我可以帮您分析环境数据、提供种植建议、诊断作物问题等。请告诉我您具体想了解什么？'
  }

  // 快捷操作
  async analyzeEnvironment(): Promise<void> {
    if (!this.currentEnvData) {
      this.addMessage('assistant', '请先选择一个检测点，以便我获取环境数据。')
      return
    }

    this.addMessage('user', '请分析当前环境状况')
    this.isLoading = true

    setTimeout(() => {
      let analysis = '📊 环境数据分析报告\n\n'
      
      // 温度分析
      if (this.currentEnvData!.temperature > 35) {
        analysis += '🌡️ 温度：偏高 (' + this.currentEnvData!.temperature + '℃)\n   建议：开启通风降温\n\n'
      } else if (this.currentEnvData!.temperature < 15) {
        analysis += '🌡️ 温度：偏低 (' + this.currentEnvData!.temperature + '℃)\n   建议：注意保温\n\n'
      } else {
        analysis += '🌡️ 温度：正常 (' + this.currentEnvData!.temperature + '℃)\n\n'
      }

      // 湿度分析
      if (this.currentEnvData!.humidity < 40) {
        analysis += '💧 湿度：偏低 (' + this.currentEnvData!.humidity + '%)\n   建议：增加灌溉或喷雾\n\n'
      } else {
        analysis += '💧 湿度：正常 (' + this.currentEnvData!.humidity + '%)\n\n'
      }

      // 土壤湿度分析
      if (this.currentEnvData!.soilMoisture < 30) {
        analysis += '🌱 土壤湿度：严重缺水 (' + this.currentEnvData!.soilMoisture + '%)\n   建议：立即灌溉\n\n'
      } else if (this.currentEnvData!.soilMoisture < 40) {
        analysis += '🌱 土壤湿度：偏干 (' + this.currentEnvData!.soilMoisture + '%)\n   建议：适时灌溉\n\n'
      } else {
        analysis += '🌱 土壤湿度：正常 (' + this.currentEnvData!.soilMoisture + '%)\n\n'
      }

      // 光照分析
      if (this.currentEnvData!.light < 300) {
        analysis += '☀️ 光照：不足 (' + this.currentEnvData!.light + ' lux)\n   建议：开启补光灯'
      } else {
        analysis += '☀️ 光照：充足 (' + this.currentEnvData!.light + ' lux)'
      }

      this.addMessage('assistant', analysis)
      this.isLoading = false
    }, 500)
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('🤖 AI农业助手')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Blank()

        if (this.isSimulationMode) {
          Text('模拟')
            .fontSize(12)
            .fontColor('#FF9800')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FFF3E0')
            .borderRadius(12)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      // 消息列表
      Scroll(this.scrollController) {
        Column() {
          ForEach(this.messages, (msg: ChatMessage) => {
            this.MessageBubble(msg)
          })

          // 加载中提示
          if (this.isLoading) {
            Row() {
              LoadingProgress()
                .width(20)
                .height(20)
                .color('#4CAF50')
              Text(' AI思考中...')
                .fontSize(13)
                .fontColor('#999999')
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .padding({ left: 16, top: 8, bottom: 8 })
          }
        }
        .width('100%')
        .padding({ top: 12, bottom: 12 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 快捷按钮
      Row() {
        Button('📊环境分析')
          .fontSize(12)
          .height(32)
          .backgroundColor('#E8F5E9')
          .fontColor('#4CAF50')
          .onClick(() => this.analyzeEnvironment())

        Button('🌾作物诊断')
          .fontSize(12)
          .height(32)
          .backgroundColor('#E8F5E9')
          .fontColor('#4CAF50')
          .margin({ left: 8 })
          .onClick(() => {
            this.inputText = '请帮我诊断作物生长状况'
          })

        Button('💧灌溉建议')
          .fontSize(12)
          .height(32)
          .backgroundColor('#E8F5E9')
          .fontColor('#4CAF50')
          .margin({ left: 8 })
          .onClick(() => {
            this.inputText = '请给出灌溉建议'
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor('#FAFAFA')

      // 输入区域
      Row() {
        TextInput({ placeholder: '输入您的问题...', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.inputText = value
          })
          .onSubmit(() => {
            this.sendMessage()
          })

        Button('发送')
          .width(60)
          .height(40)
          .backgroundColor('#4CAF50')
          .borderRadius(20)
          .margin({ left: 8 })
          .enabled(this.inputText.trim().length > 0 && !this.isLoading)
          .onClick(() => this.sendMessage())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      .backgroundColor(Color.White)

      // 底部导航
      NavBottom({ currentIndex: 2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  MessageBubble(msg: ChatMessage) {
    Row() {
      if (msg.role === 'user') {
        Blank()
        Column() {
          Text(msg.content)
            .fontSize(14)
            .fontColor(Color.White)
            .padding(12)
            .backgroundColor('#4CAF50')
            .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
          
          Text(msg.time)
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.End)
        .constraintSize({ maxWidth: '70%' })
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })
      } else {
        Column() {
          Row() {
            Text('🤖')
              .fontSize(16)
              .margin({ right: 6 })
          }
          
          Text(msg.content)
            .fontSize(14)
            .fontColor('#333333')
            .padding(12)
            .backgroundColor(Color.White)
            .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })
          
          Text(msg.time)
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .constraintSize({ maxWidth: '80%' })
        .margin({ left: 16, right: 16, top: 4, bottom: 4 })
        
        Blank()
      }
    }
    .width('100%')
  }

  private formatTime(timestamp: string): string {
    if (!timestamp) return ''
    let date = new Date(timestamp)
    let hour = date.getHours().toString().padStart(2, '0')
    let minute = date.getMinutes().toString().padStart(2, '0')
    return `${hour}:${minute}`
  }
}
