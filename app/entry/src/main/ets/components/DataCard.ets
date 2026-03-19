/**
 * 数据卡片组件
 * 用于展示环境监测数据
 */
@Component
export struct DataCard {
  @Prop title: string = ''
  @Prop value: string = ''
  @Prop unit: string = ''
  @Prop iconText: string = '📊'
  @Prop cardWidth: string = '45%'
  @Prop statusColor: ResourceColor = '#333333'
  public onCardClick?: () => void  // 点击回调（重命名避免与内置onClick冲突）

  build() {
    Column() {
      // 图标和标题
      Row() {
        Text(this.iconText)
          .fontSize(24)
        
        Text(this.title)
          .fontSize(13)
          .fontColor('#666666')
          .margin({ left: 8 })

        Blank()

        // 趋势图标
        Text('📈')
          .fontSize(14)
          .opacity(0.6)
      }
      .width('100%')

      // 数值
      Row() {
        Text(this.value)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.statusColor)
        Text(this.unit)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ left: 4, top: 12 })
      }
      .margin({ top: 12 })

      // 查看趋势提示
      Row() {
        Text('点击查看趋势')
          .fontSize(10)
          .fontColor('#AAAAAA')
      }
      .margin({ top: 8 })
    }
    .width(this.cardWidth)
    .padding(14)
    .backgroundColor(Color.White)
    .borderRadius(12)
    .shadow({
      radius: 8,
      color: '#1a000000',
      offsetX: 0,
      offsetY: 2
    })
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick()
      }
    })
  }
}