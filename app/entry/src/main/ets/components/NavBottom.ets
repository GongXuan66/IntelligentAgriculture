import router from '@ohos.router'

interface NavItem {
  title: string
  iconText: string
  page: string
}

@Component
export struct NavBottom {
  @Prop currentIndex: number = 0

  private navItems: NavItem[] = [
    { title: '农田', iconText: '🌾', page: 'pages/FieldListPage' },
    { title: '设备', iconText: '🔧', page: 'pages/DeviceAllPage' },
    { title: 'AI助手', iconText: '🤖', page: 'pages/AIAssistantPage' },
    { title: '我的', iconText: '👤', page: 'pages/ProfilePage' }
  ]

  build() {
    Row() {
      ForEach(this.navItems, (item: NavItem, index: number) => {
        Column() {
          Text(item.iconText)
            .fontSize(22)

          Text(item.title)
            .fontSize(11)
            .fontColor(this.currentIndex === index ? '#4CAF50' : '#999999')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.currentIndex !== index) {
            router.replaceUrl({ url: item.page })
          }
        })
      })
    }
    .width('100%')
    .height(60)
    .backgroundColor(Color.White)
    .shadow({
      radius: 8,
      color: '#1a000000',
      offsetX: 0,
      offsetY: -2
    })
  }
}