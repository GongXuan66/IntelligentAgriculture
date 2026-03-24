import { NavBottom } from '../components/NavBottom'
import { AppConfig } from '../config/AppConfig'
import { AppState } from '../config/AppState'
import { Farm } from '../models/Farm'
import { FarmService } from '../services/FarmService'
import { DeviceService } from '../services/DeviceService'
import { AlarmService } from '../services/AlarmService'
import router from '@ohos.router'

/**
 * 我的页面 - 个人中心
 */
@Entry
@Component
struct ProfilePage {
  @State isSimulationMode: boolean = false
  @State fieldCount: number = 0
  @State pointCount: number = 0
  @State deviceCount: number = 0
  @State alarmCount: number = 0
  @State userName: string = '农户用户'
  @State userId: string = 'farmer_001'
  
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private readonly appState: AppState = AppState.getInstance()
  private readonly farmService: FarmService = new FarmService()
  private readonly deviceService: DeviceService = new DeviceService()
  private readonly alarmService: AlarmService = AlarmService.getInstance()

  async aboutToAppear() {
    this.isSimulationMode = this.appConfig.simulationMode
    await this.loadStats()
  }

  async loadStats() {
    try {
      // 获取农场统计
      const farms = await this.farmService.getFarmList(true)
      this.fieldCount = farms.length
      
      let totalPoints = 0
      for (const farm of farms) {
        const detail = await this.farmService.getFarmDetail(farm.id!)
        if (detail && detail.points) {
          totalPoints += detail.points.length
        }
      }
      this.pointCount = totalPoints

      // 获取设备统计
      const devices = await this.deviceService.getDeviceList()
      this.deviceCount = devices.length

      // 获取报警统计
      this.alarmCount = await this.alarmService.getUnprocessedCount()
    } catch (error) {
      console.error('加载统计数据失败:', error)
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('我的')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

      Scroll() {
        Column() {
          // 用户信息卡片
          this.UserInfoCard()

          // 数据统计
          this.StatsSection()

          // 功能列表
          this.MenuSection()

          // 关于信息
          this.AboutSection()
        }
        .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部导航
      NavBottom({ currentIndex: 3 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  @Builder
  UserInfoCard() {
    Column() {
      Row() {
        // 头像
        Column() {
          Text('👤')
            .fontSize(40)
        }
        .width(70)
        .height(70)
        .backgroundColor('#E8F5E9')
        .borderRadius(35)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(this.userName)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')

          Text('ID: ' + this.userId)
            .fontSize(13)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })

        Blank()

        // 模拟模式开关
        Column() {
          Toggle({ type: ToggleType.Switch, isOn: this.isSimulationMode })
            .selectedColor('#4CAF50')
            .onChange((isOn: boolean) => {
              this.isSimulationMode = isOn
              this.appConfig.simulationMode = isOn
            })
          
          Text('模拟模式')
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  StatsSection() {
    Column() {
      Text('📊 数据统计')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')

      Row() {
        this.StatItem('🌾', '地块', this.fieldCount, '#4CAF50')
        this.StatItem('📍', '检测点', this.pointCount, '#2196F3')
        this.StatItem('🔧', '设备', this.deviceCount, '#FF9800')
        this.StatItem('🔔', '报警', this.alarmCount, '#F44336')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 16 })
    }
    .width('100%')
    .padding(16)
    .margin({ top: 16 })
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  StatItem(icon: string, label: string, count: number, color: ResourceColor) {
    Column() {
      Text(icon)
        .fontSize(24)

      Text(count.toString())
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
        .margin({ top: 8 })

      Text(label)
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 4 })
    }
    .width('25%')
    .padding(8)
  }

  @Builder
  MenuSection() {
    Column() {
      Text('⚙️ 系统设置')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
        .width('100%')

      // 菜单项
      this.MenuItem('🔔 报警阈值设置', '设置温度、湿度等报警阈值', () => {
        // TODO: 跳转到阈值设置页面
      })

      this.MenuItem('🌐 网络配置', '配置服务器地址和端口', () => {
        // TODO: 跳转到网络配置页面
      })

      this.MenuItem('📡 数据同步', '同步本地数据到服务器', () => {
        // TODO: 执行数据同步
      })

      this.MenuItem('🗑️ 清除缓存', '清除本地缓存数据', () => {
        // TODO: 清除缓存
      })
    }
    .width('100%')
    .padding(16)
    .margin({ top: 16 })
    .backgroundColor(Color.White)
    .borderRadius(16)
  }

  @Builder
  MenuItem(title: string, desc: string, action: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#333333')

        Text(desc)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('>')
        .fontSize(16)
        .fontColor('#CCCCCC')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .onClick(action)
  }

  @Builder
  AboutSection() {
    Column() {
      Row() {
        Text('📱 关于我们')
          .fontSize(15)
          .fontColor('#333333')

        Blank()

        Text('v1.0.0')
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      Row() {
        Text('📝 用户协议')
          .fontSize(15)
          .fontColor('#333333')

        Blank()

        Text('>')
          .fontSize(16)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })

      Row() {
        Text('🔒 隐私政策')
          .fontSize(15)
          .fontColor('#333333')

        Blank()

        Text('>')
          .fontSize(16)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .padding({ top: 12, bottom: 12 })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 4 })
    .margin({ top: 16 })
    .backgroundColor(Color.White)
    .borderRadius(16)
  }
}
