/**
 * Markdown渲染组件
 * 支持标题、粗体、列表等常见Markdown格式
 */

interface MarkdownLine {
  type: number  // 0=text, 1=title1, 2=title2, 3=title3, 4=bullet, 5=number
  content: string
  number: number
}

@Component
export struct MarkdownText {
  @Prop content: string = ''
  @Prop fontSize: number = 14
  @Prop fontColor: string = '#333333'
  @Prop lineHeight: number = 22
  @State parsedLines: MarkdownLine[] = []

  aboutToAppear() {
    this.parsedLines = this.parseMarkdown()
  }

  aboutToUpdate() {
    this.parsedLines = this.parseMarkdown()
  }

  build() {
    Column() {
      ForEach(this.parsedLines, (line: MarkdownLine, index: number) => {
        // 空行
        if (line.type === 0 && line.content === '') {
          Blank()
            .height(8)
        }
        // 标题1
        else if (line.type === 1) {
          Text(line.content)
            .fontSize(this.fontSize + 6)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.fontColor)
            .lineHeight(this.lineHeight + 8)
            .margin({ top: 8, bottom: 4 })
        }
        // 标题2
        else if (line.type === 2) {
          Text(line.content)
            .fontSize(this.fontSize + 4)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.fontColor)
            .lineHeight(this.lineHeight + 6)
            .margin({ top: 6, bottom: 3 })
        }
        // 标题3
        else if (line.type === 3) {
          Text(line.content)
            .fontSize(this.fontSize + 2)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.fontColor)
            .lineHeight(this.lineHeight + 4)
            .margin({ top: 4, bottom: 2 })
        }
        // 无序列表
        else if (line.type === 4) {
          Row() {
            Text('• ')
              .fontSize(this.fontSize)
              .fontColor(this.fontColor)
            Text(line.content)
              .fontSize(this.fontSize)
              .fontColor(this.fontColor)
              .lineHeight(this.lineHeight)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        // 有序列表
        else if (line.type === 5) {
          Row() {
            Text(line.number + '. ')
              .fontSize(this.fontSize)
              .fontColor(this.fontColor)
            Text(line.content)
              .fontSize(this.fontSize)
              .fontColor(this.fontColor)
              .lineHeight(this.lineHeight)
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        }
        // 普通文本
        else {
          Text(line.content)
            .fontSize(this.fontSize)
            .fontColor(this.fontColor)
            .lineHeight(this.lineHeight)
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 解析Markdown文本为行列表
   */
  private parseMarkdown(): MarkdownLine[] {
    const lines: MarkdownLine[] = []
    const rawLines = this.content.split('\n')

    for (let i = 0; i < rawLines.length; i++) {
      const rawLine = rawLines[i]
      const trimmedLine = rawLine.trim()
      
      if (trimmedLine === '') {
        lines.push({ type: 0, content: '', number: 0 })
        continue
      }

      // 标题检测
      if (trimmedLine.startsWith('### ')) {
        lines.push({ type: 3, content: trimmedLine.substring(4), number: 0 })
      } else if (trimmedLine.startsWith('## ')) {
        lines.push({ type: 2, content: trimmedLine.substring(3), number: 0 })
      } else if (trimmedLine.startsWith('# ')) {
        lines.push({ type: 1, content: trimmedLine.substring(2), number: 0 })
      }
      // 无序列表检测
      else if (trimmedLine.startsWith('- ') || trimmedLine.startsWith('• ')) {
        lines.push({ type: 4, content: trimmedLine.substring(2), number: 0 })
      }
      // 有序列表检测
      else if (this.isNumberedList(trimmedLine)) {
        const result = this.parseNumberedLine(trimmedLine)
        lines.push(result)
      }
      // 普通文本
      else {
        lines.push({ type: 0, content: trimmedLine, number: 0 })
      }
    }

    return lines
  }

  private isNumberedList(text: string): boolean {
    const match = text.match(/^(\d+)\.\s/)
    return match !== null
  }

  private parseNumberedLine(text: string): MarkdownLine {
    const match = text.match(/^(\d+)\.\s(.*)$/)
    if (match !== null && match.length >= 3) {
      return { 
        type: 5, 
        content: match[2],
        number: parseInt(match[1])
      }
    }
    return { type: 0, content: text, number: 0 }
  }
}
