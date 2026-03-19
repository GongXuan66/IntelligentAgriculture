import { AlarmRecord, AlarmType } from '../models/Alarm'

/**
 * 报警卡片组件
 */
@Component
export struct AlarmCard {
  @Prop record: AlarmRecord = new AlarmRecord()

  build() {
    Row() {
      // 报警图标
      Text('⚠️')
        .fontSize(28)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)

      // 报警信息
      Column() {
        Text(this.record.alarmType)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
        
        Text(`当前值: ${this.record.alarmValue.toFixed(1)}, 阈值: ${this.record.threshold}`)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
        
        Text(this.formatTime(this.record.time))
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(10)
    .border({ width: 1, color: '#FFEBEE' })
  }

  /**
   * 格式化时间
   */
  private formatTime(time: string): string {
    if (!time) return '--'
    let date = new Date(time)
    let month = date.getMonth() + 1
    let day = date.getDate()
    let hour = date.getHours().toString().padStart(2, '0')
    let minute = date.getMinutes().toString().padStart(2, '0')
    return `${month}/${day} ${hour}:${minute}`
  }
}