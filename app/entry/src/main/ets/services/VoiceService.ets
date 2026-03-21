import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';

const TAG = '[VoiceService]';
const MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';

/**
 * 语音识别状态
 */
export enum VoiceRecognitionState {
  IDLE = 'idle',           // 空闲
  LISTENING = 'listening', // 正在监听
  PROCESSING = 'processing', // 正在处理
  ERROR = 'error'          // 错误
}

/**
 * 语音识别结果
 */
export interface VoiceResult {
  text: string;            // 识别文本
  isFinal: boolean;        // 是否为最终结果
  confidence: number;      // 置信度
}

/**
 * 语音识别回调接口
 */
export interface VoiceRecognitionCallback {
  onStateChange?: (state: VoiceRecognitionState) => void;
  onResult?: (result: VoiceResult) => void;
  onError?: (errorCode: number, errorMessage: string) => void;
}

/**
 * 语音识别服务
 * 封装 HarmonyOS CoreSpeechKit 的语音识别能力
 */
export class VoiceService {
  private static instance: VoiceService;
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = '';
  private callback: VoiceRecognitionCallback | null = null;
  private currentState: VoiceRecognitionState = VoiceRecognitionState.IDLE;

  private constructor() {
    this.sessionId = this.generateSessionId();
  }

  /**
   * 获取单例实例
   */
  static getInstance(): VoiceService {
    if (!VoiceService.instance) {
      VoiceService.instance = new VoiceService();
    }
    return VoiceService.instance;
  }

  /**
   * 初始化语音识别引擎
   */
  async init(): Promise<boolean> {
    if (this.asrEngine) {
      console.info(TAG, '引擎已存在，无需重复初始化');
      return true;
    }

    return new Promise<boolean>((resolve) => {
      const extraParam: Record<string, Object> = {
        "locate": "CN",
        "recognizerMode": "short"  // 短语音模式，适合控制命令
      };
      
      const initParamsInfo: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',  // 中文
        online: 1,          // 在线模式
        extraParams: extraParam
      };

      speechRecognizer.createEngine(initParamsInfo, (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
        if (!err && engine) {
          console.info(TAG, '语音识别引擎创建成功');
          this.asrEngine = engine;
          this.setupListener();
          resolve(true);
        } else {
          console.error(TAG, `创建引擎失败: ${err?.code}, ${err?.message}`);
          resolve(false);
        }
      });
    });
  }

  /**
   * 设置识别监听器
   */
  private setupListener(): void {
    if (!this.asrEngine) return;

    const listener: speechRecognizer.RecognitionListener = {
      // 开始识别回调
      onStart: (sessionId: string, eventMessage: string) => {
        console.info(TAG, `开始识别: sessionId=${sessionId}`);
        this.updateState(VoiceRecognitionState.LISTENING);
      },

      // 事件回调
      onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
        console.info(TAG, `事件: code=${eventCode}, message=${eventMessage}`);
      },

      // 识别结果回调
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        console.info(TAG, `识别结果: ${JSON.stringify(result)}`);
        
        const voiceResult: VoiceResult = {
          text: result.result || '',
          isFinal: result.isFinal || false,
          confidence: 1.0
        };

        this.callback?.onResult?.(voiceResult);

        // 如果是最终结果，更新状态
        if (voiceResult.isFinal) {
          this.updateState(VoiceRecognitionState.PROCESSING);
        }
      },

      // 识别完成回调
      onComplete: (sessionId: string, eventMessage: string) => {
        console.info(TAG, `识别完成: ${eventMessage}`);
        this.updateState(VoiceRecognitionState.IDLE);
      },

      // 错误回调
      onError: (sessionId: string, errorCode: number, errorMessage: string) => {
        console.error(TAG, `识别错误: code=${errorCode}, message=${errorMessage}`);
        this.updateState(VoiceRecognitionState.ERROR);
        this.callback?.onError?.(errorCode, errorMessage);
        // 错误后恢复到空闲状态
        setTimeout(() => {
          this.updateState(VoiceRecognitionState.IDLE);
        }, 1000);
      }
    };

    this.asrEngine.setListener(listener);
  }

  /**
   * 开始语音识别
   */
  async startListening(callback: VoiceRecognitionCallback): Promise<boolean> {
    this.callback = callback;

    // 检查并请求麦克风权限
    const hasPermission = await this.requestMicrophonePermission();
    if (!hasPermission) {
      this.callback.onError?.(1002200012, '麦克风权限未授权');
      return false;
    }

    // 确保引擎已初始化
    if (!this.asrEngine) {
      const initialized = await this.init();
      if (!initialized) {
        this.callback.onError?.(1002200001, '语音识别引擎初始化失败');
        return false;
      }
    }

    // 如果正在识别，先停止
    if (this.currentState === VoiceRecognitionState.LISTENING) {
      this.cancel();
      await this.delay(300);
    }

    try {
      // 生成新的会话ID
      this.sessionId = this.generateSessionId();

      const audioParam: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      };

      const extraParam: Record<string, Object> = {
        "recognitionMode": 0,      // 标准识别模式
        "vadBegin": 3000,          // 语音开始超时 3秒
        "vadEnd": 2000,            // 语音结束超时 2秒
        "maxAudioDuration": 20000  // 最大录音时长 20秒（API要求最小20000）
      };

      const recognizerParams: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: audioParam,
        extraParams: extraParam
      };

      console.info(TAG, `开始监听: sessionId=${this.sessionId}`);
      this.asrEngine!.startListening(recognizerParams);
      this.updateState(VoiceRecognitionState.LISTENING);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `启动识别失败: ${err.message}`);
      this.callback.onError?.(err.code, err.message);
      return false;
    }
  }

  /**
   * 停止识别（完成当前识别）
   */
  finish(): void {
    if (this.asrEngine && this.sessionId) {
      console.info(TAG, `完成识别: sessionId=${this.sessionId}`);
      this.asrEngine.finish(this.sessionId);
    }
  }

  /**
   * 取消识别
   */
  cancel(): void {
    if (this.asrEngine && this.sessionId) {
      console.info(TAG, `取消识别: sessionId=${this.sessionId}`);
      this.asrEngine.cancel(this.sessionId);
      this.updateState(VoiceRecognitionState.IDLE);
    }
  }

  /**
   * 释放资源
   */
  release(): void {
    if (this.asrEngine) {
      console.info(TAG, '释放语音识别引擎');
      this.asrEngine.shutdown();
      this.asrEngine = null;
    }
    this.callback = null;
    this.updateState(VoiceRecognitionState.IDLE);
  }

  /**
   * 获取当前状态
   */
  getState(): VoiceRecognitionState {
    return this.currentState;
  }

  /**
   * 更新状态
   */
  private updateState(state: VoiceRecognitionState): void {
    if (this.currentState !== state) {
      this.currentState = state;
      this.callback?.onStateChange?.(state);
    }
  }

  /**
   * 生成会话ID
   */
  private generateSessionId(): string {
    return `session_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  }

  /**
   * 延迟函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 查询支持的语言
   */
  async querySupportedLanguages(): Promise<string[]> {
    if (!this.asrEngine) {
      return [];
    }

    return new Promise<string[]>((resolve) => {
      const query: speechRecognizer.LanguageQuery = {
        sessionId: this.sessionId
      };

      this.asrEngine!.listLanguages(query, (err: BusinessError, languages: string[]) => {
        if (!err) {
          console.info(TAG, `支持的语言: ${JSON.stringify(languages)}`);
          resolve(languages);
        } else {
          console.error(TAG, `查询语言失败: ${err.message}`);
          resolve([]);
        }
      });
    });
  }

  /**
   * 检查并请求麦克风权限
   */
  private async requestMicrophonePermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const context = getContext(this) as common.UIAbilityContext;
      
      // 先检查是否已有权限
      const grantStatus = await atManager.checkAccessToken(
        context.applicationInfo.accessTokenId,
        MICROPHONE_PERMISSION
      );
      
      if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        console.info(TAG, '麦克风权限已授权');
        return true;
      }
      
      // 请求权限
      console.info(TAG, '请求麦克风权限...');
      const result = await atManager.requestPermissionsFromUser(context, [MICROPHONE_PERMISSION]);
      
      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        console.info(TAG, '麦克风权限授权成功');
        return true;
      } else {
        console.error(TAG, '麦克风权限授权失败');
        return false;
      }
    } catch (error) {
      const err = error as BusinessError;
      console.error(TAG, `权限请求异常: ${err.message}`);
      return false;
    }
  }
}
