import { NavBottom } from '../components/NavBottom'
import { MarkdownText } from '../components/MarkdownText'
import { HttpClient } from '../web/HttpClient'
import { AppConfig } from '../config/AppConfig'
import { AppState } from '../config/AppState'
import { EnvironmentData } from '../models/EnvironmentData'
import { SensorService } from '../services/SensorService'
import { DeviceService } from '../services/DeviceService'
import { IrrigationService } from '../services/IrrigationService'
import { PreferencesService, ChatHistoryItem, ChatSession } from '../services/PreferencesService'
import { Device, DeviceType } from '../models/Device'

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
 * 设备控制意图
 */
interface DeviceIntent {
  action: string
  device: string
  command: string
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
  @State deviceList: Device[] = []
  // 会话管理
  @State sessionList: ChatSession[] = []
  @State currentSession: ChatSession | null = null
  @State showSidebar: boolean = false
  
  private readonly sensorService: SensorService = new SensorService()
  private readonly deviceService: DeviceService = new DeviceService()
  private readonly irrigationService: IrrigationService = new IrrigationService()
  private readonly prefsService: PreferencesService = PreferencesService.getInstance()
  private readonly appState: AppState = AppState.getInstance()
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private scrollController: Scroller = new Scroller()

  async aboutToAppear() {
    this.isSimulationMode = this.appConfig.simulationMode
    
    // 加载当前环境数据
    const pointId = this.appState.currentPoint?.id
    if (pointId) {
      this.currentEnvData = await this.sensorService.getEnvironmentData(pointId)
      this.deviceList = await this.deviceService.getDeviceList(pointId)
    } else {
      this.deviceList = await this.deviceService.getDeviceList()
    }
    
    // 加载会话列表
    await this.loadSessionList()
  }

  /**
   * 加载会话列表
   */
  async loadSessionList(): Promise<void> {
    try {
      this.sessionList = await this.prefsService.getAISessionList()
      
      // 获取当前会话
      this.currentSession = await this.prefsService.getCurrentSession()
      this.sessionId = this.currentSession.id
      
      // 加载当前会话的消息
      await this.loadCurrentSessionMessages()
    } catch (error) {
      console.error('加载会话列表失败:', error)
      await this.createNewSession()
    }
  }

  /**
   * 加载当前会话的消息
   */
  async loadCurrentSessionMessages(): Promise<void> {
    if (!this.currentSession) {
      this.showWelcomeMessage()
      return
    }
    
    if (this.currentSession.messages.length > 0) {
      const loadedMessages: ChatMessage[] = []
      for (let i = 0; i < this.currentSession!.messages.length; i++) {
        const item = this.currentSession!.messages[i]
        const msg: ChatMessage = {
          role: item.role,
          content: item.content,
          time: this.formatTime(item.time)
        }
        loadedMessages.push(msg)
      }
      this.messages = loadedMessages
      
      setTimeout(() => {
        this.scrollController.scrollEdge(Edge.Bottom)
      }, 100)
    } else {
      this.showWelcomeMessage()
    }
  }

  /**
   * 创建新会话
   */
  async createNewSession(): Promise<void> {
    try {
      this.currentSession = await this.prefsService.createAISession()
      this.sessionId = this.currentSession.id
      this.sessionList = await this.prefsService.getAISessionList()
      this.messages = []
      this.showWelcomeMessage()
      this.showSidebar = false
    } catch (error) {
      console.error('创建新会话失败:', error)
    }
  }

  /**
   * 切换会话
   */
  async switchSession(sessionId: string): Promise<void> {
    try {
      await this.prefsService.setCurrentSessionId(sessionId)
      this.currentSession = await this.prefsService.getAISession(sessionId)
      if (this.currentSession) {
        this.sessionId = this.currentSession.id
        await this.loadCurrentSessionMessages()
      }
      this.showSidebar = false
    } catch (error) {
      console.error('切换会话失败:', error)
    }
  }

  /**
   * 删除会话
   */
  async deleteSession(sessionId: string): Promise<void> {
    try {
      await this.prefsService.deleteAISession(sessionId)
      this.sessionList = await this.prefsService.getAISessionList()
      
      // 如果删除的是当前会话，创建新会话
      if (this.currentSession && this.currentSession.id === sessionId) {
        if (this.sessionList.length > 0) {
          await this.switchSession(this.sessionList[0].id)
        } else {
          await this.createNewSession()
        }
      }
    } catch (error) {
      console.error('删除会话失败:', error)
    }
  }

  /**
   * 显示欢迎消息
   */
  private showWelcomeMessage(): void {
    this.addMessage('assistant', '您好！我是农业AI助手，可以帮您：\n\n📊 分析作物生长状况\n🌾 诊断病虫害问题\n💧 提供灌溉建议\n🌡️ 监控环境数据\n\n### 设备控制\n我可以直接帮您操作设备，例如：\n- 打开水泵 / 关闭水泵\n- 开启风扇 / 关闭风扇\n- 开灯 / 关灯 / 设置亮度\n- 开始灌溉 / 停止灌溉\n\n请问有什么可以帮助您的？', false)
  }

  private addMessage(role: string, content: string, saveToStorage: boolean = true): void {
    const now = new Date().toISOString()
    let msg: ChatMessage = {
      role: role,
      content: content,
      time: this.formatTime(now)
    }
    this.messages = [...this.messages, msg]
    
    // 保存到本地存储
    if (saveToStorage) {
      this.prefsService.addAIChatMessage(role, content).catch((err: Error) => {
        console.error('保存对话记录失败:', err.message)
      })
    }
    
    // 滚动到底部
    setTimeout(() => {
      this.scrollController.scrollEdge(Edge.Bottom)
    }, 100)
  }

  /**
   * 解析设备控制意图
   */
  private parseDeviceIntent(message: string): DeviceIntent | null {
    const lowerMsg = message.toLowerCase()
    
    // 水泵控制
    if (lowerMsg.includes('水泵') || lowerMsg.includes('抽水') || lowerMsg.includes('浇水')) {
      if (lowerMsg.includes('开') || lowerMsg.includes('启动') || lowerMsg.includes('开始')) {
        const intent: DeviceIntent = { action: 'control', device: 'pump', command: 'on' }
        return intent
      }
      if (lowerMsg.includes('关') || lowerMsg.includes('停止') || lowerMsg.includes('关闭')) {
        const intent: DeviceIntent = { action: 'control', device: 'pump', command: 'off' }
        return intent
      }
    }
    
    // 风扇控制
    if (lowerMsg.includes('风扇') || lowerMsg.includes('通风') || lowerMsg.includes('排风')) {
      if (lowerMsg.includes('开') || lowerMsg.includes('启动') || lowerMsg.includes('开始')) {
        const intent: DeviceIntent = { action: 'control', device: 'fan', command: 'on' }
        return intent
      }
      if (lowerMsg.includes('关') || lowerMsg.includes('停止') || lowerMsg.includes('关闭')) {
        const intent: DeviceIntent = { action: 'control', device: 'fan', command: 'off' }
        return intent
      }
    }
    
    // 灯光控制
    if (lowerMsg.includes('灯') || lowerMsg.includes('补光') || lowerMsg.includes('光照')) {
      if (lowerMsg.includes('开') || lowerMsg.includes('启动') || lowerMsg.includes('开始')) {
        const intent: DeviceIntent = { action: 'control', device: 'led', command: 'on' }
        return intent
      }
      if (lowerMsg.includes('关') || lowerMsg.includes('停止') || lowerMsg.includes('关闭')) {
        const intent: DeviceIntent = { action: 'control', device: 'led', command: 'off' }
        return intent
      }
      // 设置亮度
      const brightnessMatch = message.match(/亮度.*?(\d+)/)
      if (brightnessMatch !== null && brightnessMatch.length > 1) {
        const brightness = parseInt(brightnessMatch[1] as string)
        const intent: DeviceIntent = { action: 'control', device: 'led', command: `brightness:${brightness}` }
        return intent
      }
    }
    
    // 水阀控制
    if (lowerMsg.includes('水阀') || lowerMsg.includes('阀门')) {
      if (lowerMsg.includes('开') || lowerMsg.includes('启动')) {
        const intent: DeviceIntent = { action: 'control', device: 'valve', command: 'on' }
        return intent
      }
      if (lowerMsg.includes('关') || lowerMsg.includes('关闭')) {
        const intent: DeviceIntent = { action: 'control', device: 'valve', command: 'off' }
        return intent
      }
    }
    
    // 灌溉控制
    if (lowerMsg.includes('灌溉') && !lowerMsg.includes('建议')) {
      if (lowerMsg.includes('开始') || lowerMsg.includes('开') || lowerMsg.includes('启动')) {
        const intent: DeviceIntent = { action: 'irrigation', device: 'irrigation', command: 'start' }
        return intent
      }
      if (lowerMsg.includes('停止') || lowerMsg.includes('关') || lowerMsg.includes('结束')) {
        const intent: DeviceIntent = { action: 'irrigation', device: 'irrigation', command: 'stop' }
        return intent
      }
    }
    
    return null
  }

  /**
   * 执行设备控制
   */
  async executeDeviceControl(intent: DeviceIntent): Promise<string> {
    let success = false
    let deviceName = ''
    
    try {
      if (intent.action === 'irrigation') {
        const pointId = this.appState.currentPoint?.id || 1
        if (intent.command === 'start') {
          // 默认灌溉30秒
          const result = await this.irrigationService.startIrrigation(pointId, 30, 1)
          success = result !== null
          deviceName = '灌溉系统'
        } else {
          await this.irrigationService.stopIrrigation(pointId)
          success = true
          deviceName = '灌溉系统'
        }
      } else {
        // 设备控制
        switch (intent.device) {
          case 'pump':
            deviceName = '水泵'
            success = await this.deviceService.controlDevice('pump_001', intent.command)
            break
          case 'fan':
            deviceName = '风扇'
            success = await this.deviceService.controlDevice('fan_001', intent.command)
            break
          case 'led':
            deviceName = '补光灯'
            success = await this.deviceService.controlDevice('led_001', intent.command)
            break
          case 'valve':
            deviceName = '水阀'
            success = await this.deviceService.controlDevice('valve_001', intent.command)
            break
        }
      }
      
      if (success) {
        const actionText = intent.command === 'on' || intent.command === 'start' ? '已开启' : 
                          intent.command === 'off' || intent.command === 'stop' ? '已关闭' :
                          intent.command.startsWith('brightness') ? `亮度已设置为${intent.command.split(':')[1]}%` : '操作成功'
        return `✅ **${deviceName}** ${actionText}\n\n操作已执行成功。`
      } else {
        return `❌ **${deviceName}** 操作失败\n\n可能是网络问题或设备离线，请稍后重试。`
      }
    } catch (error) {
      console.error('设备控制失败:', error)
      return `❌ **${deviceName}** 操作出错\n\n错误信息：${error}\n\n请检查设备状态后重试。`
    }
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
      // 先检查是否是设备控制意图
      const deviceIntent = this.parseDeviceIntent(userMessage)
      if (deviceIntent) {
        const result = await this.executeDeviceControl(deviceIntent)
        this.addMessage('assistant', result)
        this.isLoading = false
        return
      }

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

  // 快捷灌溉操作
  async quickIrrigation(): Promise<void> {
    this.addMessage('user', '开始灌溉')
    this.isLoading = true
    
    const pointId = this.appState.currentPoint?.id || 1
    try {
      const result = await this.irrigationService.startIrrigation(pointId, 30, 1)
      if (result) {
        this.addMessage('assistant', '✅ **灌溉系统** 已启动\n\n- 灌溉时长：30秒\n- 检测点：' + pointId + '\n\n灌溉过程中您可以在农田页面查看进度。')
      } else {
        this.addMessage('assistant', '❌ 启动灌溉失败，请检查设备状态后重试。')
      }
    } catch (error) {
      this.addMessage('assistant', '❌ 启动灌溉时出错：' + error)
    } finally {
      this.isLoading = false
    }
  }

  // 快捷风扇控制
  async quickFanControl(): Promise<void> {
    this.addMessage('user', '开启风扇')
    this.isLoading = true
    
    try {
      const success = await this.deviceService.turnOnFan()
      if (success) {
        this.addMessage('assistant', '✅ **通风风扇** 已开启\n\n风扇正在运行，有助于降低温度和改善空气流通。\n\n需要关闭时请告诉我"关闭风扇"。')
      } else {
        this.addMessage('assistant', '❌ 开启风扇失败，请检查设备状态后重试。')
      }
    } catch (error) {
      this.addMessage('assistant', '❌ 开启风扇时出错：' + error)
    } finally {
      this.isLoading = false
    }
  }

  // 清空当前会话（删除并创建新会话）
  async clearHistory(): Promise<void> {
    if (this.currentSession) {
      await this.deleteSession(this.currentSession.id)
    } else {
      await this.createNewSession()
    }
  }

  build() {
    Stack() {
      // 主内容区域
      Column() {
        // 标题栏
        Row() {
          // 打开侧边栏按钮
          Text('☰')
            .fontSize(22)
            .fontColor('#666666')
            .padding(8)
            .onClick(() => { this.showSidebar = true })

          Text('🤖 AI农业助手')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)
            .margin({ left: 8 })

          // 新建会话按钮
          Text('✚')
            .fontSize(20)
            .fontColor('#4CAF50')
            .padding(8)
            .onClick(() => this.createNewSession())

          if (this.isSimulationMode) {
            Text('模拟')
              .fontSize(12)
              .fontColor('#FF9800')
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor('#FFF3E0')
              .borderRadius(12)
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .height(56)
        .padding({ left: 8, right: 16 })
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

        Button('💧开始灌溉')
          .fontSize(12)
          .height(32)
          .backgroundColor('#E3F2FD')
          .fontColor('#2196F3')
          .margin({ left: 8 })
          .onClick(() => this.quickIrrigation())

        Button('💨开启风扇')
          .fontSize(12)
          .height(32)
          .backgroundColor('#FFF3E0')
          .fontColor('#FF9800')
          .margin({ left: 8 })
          .onClick(() => this.quickFanControl())
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

    // 侧边栏
    if (this.showSidebar) {
      // 遮罩层
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => { this.showSidebar = false })

      // 侧边栏内容
      Column() {
        // 侧边栏标题
        Row() {
          Text('对话历史')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
            .layoutWeight(1)

          Text('✕')
            .fontSize(20)
            .fontColor('#999999')
            .padding(8)
            .onClick(() => { this.showSidebar = false })
        }
        .width('100%')
        .padding({ left: 16, right: 8, top: 12, bottom: 12 })
        .backgroundColor(Color.White)

        // 新建对话按钮
        Row() {
          Text('✚ 新建对话')
            .fontSize(15)
            .fontColor('#4CAF50')
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#E8F5E9')
        .borderRadius(8)
        .margin({ left: 12, right: 12, top: 8, bottom: 8 })
        .onClick(() => this.createNewSession())

        // 会话列表
        List() {
          ForEach(this.sessionList, (session: ChatSession) => {
            ListItem() {
              Row() {
                Column() {
                  Text(session.title)
                    .fontSize(14)
                    .fontColor(this.currentSession?.id === session.id ? '#4CAF50' : '#333333')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')

                  Text(this.formatDate(session.updatedAt))
                    .fontSize(11)
                    .fontColor('#999999')
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // 删除按钮
                Text('🗑️')
                  .fontSize(16)
                  .padding(8)
                  .onClick(() => this.deleteSession(session.id))
              }
              .width('100%')
              .padding({ left: 12, right: 8, top: 10, bottom: 10 })
              .backgroundColor(this.currentSession?.id === session.id ? '#E8F5E9' : Color.White)
              .borderRadius(8)
              .margin({ left: 12, right: 12, top: 4, bottom: 4 })
            }
            .onClick(() => this.switchSession(session.id))
          })
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 8 })
      }
      .width('75%')
      .height('100%')
      .backgroundColor('#F5F5F5')
      .position({ x: 0, y: 0 })
    }
    }
    .width('100%')
    .height('100%')
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
          
          // 使用Markdown渲染AI回复
          Column() {
            MarkdownText({ 
              content: msg.content, 
              fontSize: 14, 
              fontColor: '#333333',
              lineHeight: 22
            })
          }
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

  private formatDate(timestamp: string): string {
    if (!timestamp) return ''
    let date = new Date(timestamp)
    let now = new Date()
    let diffDays = Math.floor((now.getTime() - date.getTime()) / (1000 * 60 * 60 * 24))
    
    if (diffDays === 0) {
      let hour = date.getHours().toString().padStart(2, '0')
      let minute = date.getMinutes().toString().padStart(2, '0')
      return `今天 ${hour}:${minute}`
    } else if (diffDays === 1) {
      return '昨天'
    } else if (diffDays < 7) {
      return `${diffDays}天前`
    } else {
      let month = (date.getMonth() + 1).toString().padStart(2, '0')
      let day = date.getDate().toString().padStart(2, '0')
      return `${month}-${day}`
    }
  }
}
