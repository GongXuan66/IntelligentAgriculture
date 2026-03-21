import { VoiceService, VoiceRecognitionState, VoiceResult } from '../services/VoiceService';
import { VoiceCommandParser, ParsedVoiceCommand, VoiceCommandType } from '../services/VoiceCommandParser';
import { DeviceService } from '../services/DeviceService';
import { IrrigationService } from '../services/IrrigationService';

const TAG = '[VoiceInputButton]';

/**
 * 语音命令执行结果
 */
export interface VoiceCommandResult {
  success: boolean;
  message: string;
  command?: ParsedVoiceCommand;
}

/**
 * 语音输入按钮组件
 * 提供语音识别和命令执行功能
 */
@Component
export struct VoiceInputButton {
  // 语音服务
  private voiceService: VoiceService = VoiceService.getInstance();
  // 设备服务
  private deviceService: DeviceService = new DeviceService();
  // 灌溉服务
  private irrigationService: IrrigationService = new IrrigationService();

  // 状态
  @State private isListening: boolean = false;
  @State private recognizedText: string = '';
  @State private statusText: string = '点击说话';
  @State private isProcessing: boolean = false;
  @State private showResult: boolean = false;
  @State private resultMessage: string = '';

  // 回调
  onCommandExecuted?: (result: VoiceCommandResult) => void;

  // 按钮尺寸
  @Prop buttonSize: number = 56;
  // 是否显示识别文本
  @Prop showRecognizedText: boolean = true;

  aboutToAppear(): void {
    // 初始化语音服务
    this.voiceService.init().then((success) => {
      if (!success) {
        console.warn(TAG, '语音服务初始化失败');
        this.statusText = '语音服务不可用';
      }
    });
  }

  aboutToDisappear(): void {
    // 组件销毁时不释放服务，因为服务是单例
  }

  build() {
    Column() {
      // 识别文本显示区域
      if (this.showRecognizedText && this.recognizedText) {
        Text(this.recognizedText)
          .fontSize(14)
          .fontColor('#666666')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .padding(8)
          .backgroundColor('#f5f5f5')
          .borderRadius(8)
          .margin({ bottom: 8 })
      }

      // 结果提示
      if (this.showResult && this.resultMessage) {
        Text(this.resultMessage)
          .fontSize(13)
          .fontColor(this.resultMessage.includes('成功') ? '#4CAF50' : '#f44336')
          .padding(8)
          .backgroundColor(this.resultMessage.includes('成功') ? '#E8F5E9' : '#FFEBEE')
          .borderRadius(8)
          .margin({ bottom: 8 })
          .animation({
            duration: 300,
            curve: Curve.EaseInOut
          })
      }

      // 语音按钮
      Button() {
        Column() {
          if (this.isProcessing) {
            LoadingProgress()
              .width(24)
              .height(24)
              .color(Color.White)
          } else {
            // 麦克风图标
            Text(this.isListening ? '🔴' : '🎤')
              .fontSize(24)
          }
        }
      }
      .width(this.buttonSize)
      .height(this.buttonSize)
      .borderRadius(this.buttonSize / 2)
      .backgroundColor(this.getButtonColor())
      .shadow({
        radius: this.isListening ? 16 : 8,
        color: this.isListening ? '#4CAF5050' : '#00000020',
        offsetX: 0,
        offsetY: 2
      })
      .animation({
        duration: 200,
        curve: Curve.EaseInOut
      })
      .onClick(() => {
        if (this.isProcessing) {
          return;
        }
        this.toggleListening();
      })
      .gesture(
        LongPressGesture({ repeat: false })
          .onAction(() => {
            // 长按持续录音
            this.startListening();
          })
          .onActionEnd(() => {
            // 松开结束录音
            this.finishListening();
          })
      )

      // 状态文本
      Text(this.statusText)
        .fontSize(12)
        .fontColor('#999999')
        .margin({ top: 8 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  /**
   * 获取按钮颜色
   */
  private getButtonColor(): ResourceColor {
    if (this.isListening) {
      return '#4CAF50';
    }
    if (this.isProcessing) {
      return '#9E9E9E';
    }
    return '#2196F3';
  }

  /**
   * 切换监听状态
   */
  private toggleListening(): void {
    if (this.isListening) {
      this.finishListening();
    } else {
      this.startListening();
    }
  }

  /**
   * 开始监听
   */
  private startListening(): void {
    if (this.isProcessing) {
      return;
    }

    this.recognizedText = '';
    this.showResult = false;
    this.statusText = '正在聆听...';

    this.voiceService.startListening({
      onStateChange: (state: VoiceRecognitionState) => {
        console.info(TAG, `状态变化: ${state}`);
        this.isListening = state === VoiceRecognitionState.LISTENING;
        
        switch (state) {
          case VoiceRecognitionState.IDLE:
            this.statusText = '点击说话';
            break;
          case VoiceRecognitionState.LISTENING:
            this.statusText = '正在聆听...';
            break;
          case VoiceRecognitionState.PROCESSING:
            this.statusText = '正在处理...';
            this.isProcessing = true;
            break;
          case VoiceRecognitionState.ERROR:
            this.statusText = '识别失败，请重试';
            break;
        }
      },

      onResult: (result: VoiceResult) => {
        console.info(TAG, `识别结果: ${result.text}`);
        this.recognizedText = result.text;

        // 如果是最终结果，执行命令
        if (result.isFinal) {
          this.executeCommand(result.text);
        }
      },

      onError: (errorCode: number, errorMessage: string) => {
        console.error(TAG, `识别错误: ${errorCode} - ${errorMessage}`);
        this.statusText = '识别失败';
        this.isListening = false;
        this.isProcessing = false;
        this.showResultMessage(`识别失败: ${errorMessage}`);
      }
    });
  }

  /**
   * 结束监听
   */
  private finishListening(): void {
    this.voiceService.finish();
    this.isListening = false;
  }

  /**
   * 执行语音命令
   */
  private async executeCommand(text: string): Promise<void> {
    const command = VoiceCommandParser.parse(text);
    console.info(TAG, `解析命令: ${JSON.stringify(command)}`);

    if (command.type === VoiceCommandType.UNKNOWN) {
      this.showResultMessage(`未识别的命令: "${text}"`);
      this.isProcessing = false;
      return;
    }

    const description = VoiceCommandParser.getCommandDescription(command);
    let success = false;
    let message = '';

    try {
      switch (command.type) {
        case VoiceCommandType.CONTROL_DEVICE:
          if (command.action === 'on') {
            success = await this.deviceService.turnOn(command.deviceId!);
            message = success ? `已打开${VoiceCommandParser.getCommandDescription(command).replace('打开', '')}` : '设备控制失败';
          } else if (command.action === 'off') {
            success = await this.deviceService.turnOff(command.deviceId!);
            message = success ? `已关闭${VoiceCommandParser.getCommandDescription(command).replace('关闭', '')}` : '设备控制失败';
          }
          break;
        case VoiceCommandType.START_IRRIGATION:
          try {
            const irrigationResult = await this.irrigationService.startIrrigation(1, 60, 1);
            success = irrigationResult !== null;
            message = success ? '灌溉已启动' : '启动灌溉失败';
          } catch (e) {
            success = false;
            message = '启动灌溉失败';
          }
          break;
        case VoiceCommandType.STOP_IRRIGATION:
          try {
            const currentState = IrrigationService.getIrrigationState();
            const stopResult = await this.irrigationService.stopIrrigation(currentState.currentLogId);
            success = stopResult !== null;
            message = success ? '灌溉已停止' : '停止灌溉失败';
          } catch (e) {
            success = false;
            message = '停止灌溉失败';
          }
          break;

        case VoiceCommandType.SET_BRIGHTNESS:
          success = await this.deviceService.setLedBrightness(command.value!);
          message = success ? `补光灯亮度已设置为${command.value}%` : '设置亮度失败';
          break;

        case VoiceCommandType.SET_FAN_LEVEL:
          success = await this.deviceService.controlDevice(command.deviceId!, `level:${command.value}`);
          message = success ? `风扇档位已设置为${command.value}` : '设置档位失败';
          break;
      }
    } catch (error) {
      console.error(TAG, '命令执行失败:', error);
      message = '命令执行失败';
    }

    this.showResultMessage(message);
    this.isProcessing = false;

    // 触发回调
    if (this.onCommandExecuted) {
      this.onCommandExecuted({
        success: success,
        message: message,
        command: command
      });
    }
  }

  /**
   * 显示结果消息
   */
  private showResultMessage(message: string): void {
    this.resultMessage = message;
    this.showResult = true;

    // 3秒后自动隐藏
    setTimeout(() => {
      this.showResult = false;
    }, 3000);
  }

  /**
   * 取消当前操作
   */
  public cancel(): void {
    this.voiceService.cancel();
    this.isListening = false;
    this.isProcessing = false;
    this.statusText = '点击说话';
  }
}
