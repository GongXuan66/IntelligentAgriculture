import { AlarmRecord, AlarmType } from '../models/Alarm'
import { AlarmService } from '../services/AlarmService'
import { AlarmCard } from '../components/AlarmCard'
import { NavBottom } from '../components/NavBottom'

/**
 * 报警页面
 */
@Entry
@Component
struct AlarmPage {
  @State alarmRecords: AlarmRecord[] = []
  @State unreadCount: number = 0
  @State isLoading: boolean = true

  private alarmService: AlarmService = AlarmService.getInstance()
  private refreshInterval: number = -1

  aboutToAppear() {
    this.loadAlarms()
    this.refreshInterval = setInterval(() => {
      this.loadAlarms()
    }, 5000)
  }

  aboutToDisappear() {
    if (this.refreshInterval !== -1) {
      clearInterval(this.refreshInterval)
    }
  }

  async loadAlarms() {
    this.isLoading = true
    try {
      this.alarmRecords = await this.alarmService.getAlarmList()
      this.unreadCount = await this.alarmService.getUnprocessedCount()
    } catch (error) {
      console.error('加载报警记录失败:', error)
    } finally {
      this.isLoading = false
    }
  }

  async handleAlarm(id: string) {
    let success = await this.alarmService.handleAlarm(id)
    if (success) {
      await this.loadAlarms()
    }
  }

  async clearAllAlarms() {
    let success = await this.alarmService.handleAllByPointId(1)
    if (success) {
      await this.loadAlarms()
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('报警记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#333333')

        Blank()

        if (this.unreadCount > 0) {
          Text(this.unreadCount + ' 条未处理')
            .fontSize(12)
            .fontColor('#F44336')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FFEBEE')
            .borderRadius(10)
        }
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)

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
      } else if (this.alarmRecords.length === 0) {
        Column() {
          Text('暂无报警记录')
            .fontSize(16)
            .fontColor('#999999')
          Text('系统运行正常')
            .fontSize(13)
            .fontColor('#CCCCCC')
            .margin({ top: 8 })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.alarmRecords, (record: AlarmRecord, index: number) => {
            ListItem() {
              Column() {
                Row() {
                  Column() {
                    Text(this.getAlarmTitle(record.alarmType))
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#333333')
                    Text(this.formatTime(record.time))
                      .fontSize(12)
                      .fontColor('#999999')
                      .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)

                  Blank()

                  if (!record.isRead) {
                    Button('处理')
                      .fontSize(12)
                      .height(28)
                      .backgroundColor('#4CAF50')
                      .onClick(() => this.handleAlarm(record.id))
                  } else {
                    Text('已处理')
                      .fontSize(12)
                      .fontColor('#999999')
                  }
                }
                .width('100%')

                Row() {
                  Text('报警值: ' + record.alarmValue.toFixed(1))
                    .fontSize(12)
                    .fontColor('#666666')
                  Text(' | ')
                    .fontSize(12)
                    .fontColor('#CCCCCC')
                  Text('阈值: ' + record.threshold.toFixed(1))
                    .fontSize(12)
                    .fontColor('#666666')
                }
                .margin({ top: 8 })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(12)
            }
            .margin({ top: index === 0 ? 16 : 8, left: 16, right: 16 })
          })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)

        Button('处理所有报警')
          .width('80%')
          .height(44)
          .margin({ top: 16, bottom: 16 })
          .backgroundColor('#FF5722')
          .borderRadius(22)
          .onClick(() => this.clearAllAlarms())
      }

      NavBottom({ currentIndex: 5 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#f5f5f5')
  }

  private getAlarmTitle(type: AlarmType): string {
    switch (type) {
      case AlarmType.TEMPERATURE_HIGH:
        return '温度过高报警'
      case AlarmType.TEMPERATURE_LOW:
        return '温度过低报警'
      case AlarmType.HUMIDITY_HIGH:
        return '湿度过高报警'
      case AlarmType.HUMIDITY_LOW:
        return '湿度过低报警'
      case AlarmType.LIGHT_LOW:
        return '光照不足报警'
      case AlarmType.CO2_HIGH:
        return 'CO2浓度过高报警'
      case AlarmType.SOIL_MOISTURE_LOW:
        return '土壤湿度过低报警'
      case AlarmType.DEVICE_OFFLINE:
        return '设备离线报警'
      default:
        return '未知报警'
    }
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
