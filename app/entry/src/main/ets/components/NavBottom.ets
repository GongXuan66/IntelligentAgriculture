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
    { title: '首页', iconText: '🏠', page: 'pages/Index' },
    { title: '设备', iconText: '🛠️', page: 'pages/DevicePage' },
    { title: '灌溉', iconText: '💧', page: 'pages/IrrigationPage' },
    { title: '光照', iconText: '☀️', page: 'pages/LightPage' },
    { title: '通风', iconText: '🌬️', page: 'pages/VentilationPage' },
    { title: '报警', iconText: '🔔', page: 'pages/AlarmPage' }
  ]

  build() {
    Row() {
      ForEach(this.navItems, (item: NavItem, index: number) => {
        Column() {
          Text(item.iconText)
            .fontSize(20)

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
    .height(56)
    .backgroundColor(Color.White)
    .shadow({
      radius: 8,
      color: '#1a000000',
      offsetX: 0,
      offsetY: -2
    })
  }
}
