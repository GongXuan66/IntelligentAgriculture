import { DeviceType } from '../models/Device';

const TAG = '[VoiceCommandParser]';

/**
 * 语音命令类型
 */
export enum VoiceCommandType {
  CONTROL_DEVICE = 'control_device',   // 设备控制
  START_IRRIGATION = 'start_irrigation', // 开始灌溉
  STOP_IRRIGATION = 'stop_irrigation',   // 停止灌溉
  SET_BRIGHTNESS = 'set_brightness',     // 设置亮度
  SET_FAN_LEVEL = 'set_fan_level',       // 设置风扇档位
  UNKNOWN = 'unknown'                    // 未知命令
}

/**
 * 解析后的语音命令
 */
export interface ParsedVoiceCommand {
  type: VoiceCommandType;
  deviceType?: DeviceType;
  deviceName?: string;
  deviceId?: string;
  action?: string;  // 'on' | 'off' | 'set'
  value?: number;         // 亮度/档位等数值
  originalText: string;   // 原始语音文本
  confidence: number;     // 解析置信度
}

/**
 * 设备关键词映射
 */
interface DeviceKeyword {
  type: DeviceType;
  keywords: string[];
  defaultDeviceId: string;
}

/**
 * 语音命令解析器
 * 将语音文本解析为设备控制命令
 */
export class VoiceCommandParser {
  // 设备关键词映射表
  private static readonly DEVICE_KEYWORDS: DeviceKeyword[] = [
    {
      type: DeviceType.WATER_PUMP,
      keywords: ['水泵', '抽水泵', '灌溉泵', '浇水泵', '泵'],
      defaultDeviceId: 'pump_001'
    },
    {
      type: DeviceType.LED,
      keywords: ['补光灯', 'LED灯', '灯', '照明灯', '植物灯'],
      defaultDeviceId: 'led_001'
    },
    {
      type: DeviceType.FAN,
      keywords: ['风扇', '通风扇', '排风扇', '换气扇', '风机'],
      defaultDeviceId: 'fan_001'
    },
    {
      type: DeviceType.VALVE,
      keywords: ['水阀', '阀门', '电磁阀'],
      defaultDeviceId: 'valve_001'
    }
  ];

  // 开启动作关键词
  private static readonly ON_KEYWORDS: string[] = [
    '打开', '开启', '启动', '开', '运行', '工作'
  ];

  // 关闭动作关键词
  private static readonly OFF_KEYWORDS: string[] = [
    '关闭', '关掉', '停止', '关', '停', '断开', '关闭掉'
  ];

  // 灌溉相关关键词
  private static readonly IRRIGATION_START_KEYWORDS: string[] = [
    '开始灌溉', '启动灌溉', '打开灌溉', '浇水', '灌溉开始',
    '自动灌溉', '开始浇灌', '启动浇灌'
  ];

  private static readonly IRRIGATION_STOP_KEYWORDS: string[] = [
    '停止灌溉', '关闭灌溉', '结束灌溉', '停止浇水', '停止浇灌'
  ];

  // 亮度/档位关键词
  private static readonly BRIGHTNESS_KEYWORDS: string[] = [
    '亮度', '调亮', '调暗', '亮度调'
  ];

  private static readonly LEVEL_KEYWORDS: string[] = [
    '档位', '风速', '档', '级'
  ];

  /**
   * 解析语音文本
   */
  static parse(text: string): ParsedVoiceCommand {
    const normalizedText = VoiceCommandParser.normalizeText(text);
    console.info(TAG, `解析语音: "${text}" -> "${normalizedText}"`);

    // 1. 尝试解析灌溉命令
    const irrigationCommand = VoiceCommandParser.parseIrrigationCommand(normalizedText, text);
    if (irrigationCommand) {
      return irrigationCommand;
    }

    // 2. 尝试解析设备控制命令
    const deviceCommand = VoiceCommandParser.parseDeviceCommand(normalizedText, text);
    if (deviceCommand) {
      return deviceCommand;
    }

    // 3. 返回未知命令
    return {
      type: VoiceCommandType.UNKNOWN,
      originalText: text,
      confidence: 0
    };
  }

  /**
   * 标准化文本（去除空格、标点等）
   */
  private static normalizeText(text: string): string {
    return text
      .replace(/[，。！？、；：""''（）【】\s]/g, '')
      .toLowerCase();
  }

  /**
   * 解析灌溉命令
   */
  private static parseIrrigationCommand(normalizedText: string, originalText: string): ParsedVoiceCommand | null {
    // 检查开始灌溉
    for (let i = 0; i < VoiceCommandParser.IRRIGATION_START_KEYWORDS.length; i++) {
      const keyword = VoiceCommandParser.IRRIGATION_START_KEYWORDS[i];
      if (normalizedText.includes(VoiceCommandParser.normalizeText(keyword))) {
        return {
          type: VoiceCommandType.START_IRRIGATION,
          action: 'on',
          originalText: originalText,
          confidence: 0.9
        };
      }
    }

    // 检查停止灌溉
    for (let i = 0; i < VoiceCommandParser.IRRIGATION_STOP_KEYWORDS.length; i++) {
      const keyword = VoiceCommandParser.IRRIGATION_STOP_KEYWORDS[i];
      if (normalizedText.includes(VoiceCommandParser.normalizeText(keyword))) {
        return {
          type: VoiceCommandType.STOP_IRRIGATION,
          action: 'off',
          originalText: originalText,
          confidence: 0.9
        };
      }
    }

    return null;
  }

  /**
   * 解析设备控制命令
   */
  private static parseDeviceCommand(normalizedText: string, originalText: string): ParsedVoiceCommand | null {
    // 查找设备类型
    let matchedDevice: DeviceKeyword | null = null;
    for (let i = 0; i < VoiceCommandParser.DEVICE_KEYWORDS.length; i++) {
      const device = VoiceCommandParser.DEVICE_KEYWORDS[i];
      for (let j = 0; j < device.keywords.length; j++) {
        if (normalizedText.includes(device.keywords[j])) {
          matchedDevice = device;
          break;
        }
      }
      if (matchedDevice) {
        break;
      }
    }

    if (!matchedDevice) {
      return null;
    }

    // 检查是否为亮度设置（针对LED）
    if (matchedDevice.type === DeviceType.LED) {
      const brightnessCommand = VoiceCommandParser.parseBrightnessCommand(normalizedText, originalText, matchedDevice);
      if (brightnessCommand) {
        return brightnessCommand;
      }
    }

    // 检查是否为档位设置（针对风扇）
    if (matchedDevice.type === DeviceType.FAN) {
      const levelCommand = VoiceCommandParser.parseLevelCommand(normalizedText, originalText, matchedDevice);
      if (levelCommand) {
        return levelCommand;
      }
    }

    // 检查开关动作
    let action: string | undefined = undefined;

    for (let i = 0; i < VoiceCommandParser.ON_KEYWORDS.length; i++) {
      if (normalizedText.includes(VoiceCommandParser.ON_KEYWORDS[i])) {
        action = 'on';
        break;
      }
    }

    if (!action) {
      for (let i = 0; i < VoiceCommandParser.OFF_KEYWORDS.length; i++) {
        if (normalizedText.includes(VoiceCommandParser.OFF_KEYWORDS[i])) {
          action = 'off';
          break;
        }
      }
    }

    if (action) {
      return {
        type: VoiceCommandType.CONTROL_DEVICE,
        deviceType: matchedDevice.type,
        deviceId: matchedDevice.defaultDeviceId,
        action: action,
        originalText: originalText,
        confidence: 0.85
      };
    }

    return null;
  }

  /**
   * 解析亮度设置命令
   */
  private static parseBrightnessCommand(
    normalizedText: string,
    originalText: string,
    device: DeviceKeyword
  ): ParsedVoiceCommand | null {
    // 提取数字
    const numbers = VoiceCommandParser.extractNumbers(normalizedText);
    if (numbers.length === 0) {
      return null;
    }

    // 检查亮度关键词
    let hasBrightnessKeyword = false;
    for (let i = 0; i < VoiceCommandParser.BRIGHTNESS_KEYWORDS.length; i++) {
      if (normalizedText.includes(VoiceCommandParser.BRIGHTNESS_KEYWORDS[i])) {
        hasBrightnessKeyword = true;
        break;
      }
    }

    if (!hasBrightnessKeyword && numbers.length > 0) {
      // 如果没有亮度关键词但有数字，也尝试解析（如"补光灯50"）
      hasBrightnessKeyword = true;
    }

    if (hasBrightnessKeyword && numbers.length > 0) {
      const brightness = Math.min(100, Math.max(0, numbers[0]));
      return {
        type: VoiceCommandType.SET_BRIGHTNESS,
        deviceType: device.type,
        deviceId: device.defaultDeviceId,
        action: 'set',
        value: brightness,
        originalText: originalText,
        confidence: 0.8
      };
    }

    return null;
  }

  /**
   * 解析档位设置命令
   */
  private static parseLevelCommand(
    normalizedText: string,
    originalText: string,
    device: DeviceKeyword
  ): ParsedVoiceCommand | null {
    // 提取数字
    const numbers = VoiceCommandParser.extractNumbers(normalizedText);
    if (numbers.length === 0) {
      return null;
    }

    // 检查档位关键词
    let hasLevelKeyword = false;
    for (let i = 0; i < VoiceCommandParser.LEVEL_KEYWORDS.length; i++) {
      if (normalizedText.includes(VoiceCommandParser.LEVEL_KEYWORDS[i])) {
        hasLevelKeyword = true;
        break;
      }
    }

    if (hasLevelKeyword && numbers.length > 0) {
      const level = Math.min(100, Math.max(0, numbers[0]));
      return {
        type: VoiceCommandType.SET_FAN_LEVEL,
        deviceType: device.type,
        deviceId: device.defaultDeviceId,
        action: 'set',
        value: level,
        originalText: originalText,
        confidence: 0.8
      };
    }

    return null;
  }

  /**
   * 从文本中提取数字
   */
  private static extractNumbers(text: string): number[] {
    const numbers: number[] = [];
    
    // 匹配阿拉伯数字
    const arabicPattern = /\d+/g;
    let match = arabicPattern.exec(text);
    while (match !== null) {
      numbers.push(parseInt(match[0], 10));
      match = arabicPattern.exec(text);
    }

    // 匹配中文数字
    const chineseNumbers: Map<string, number> = new Map();
    chineseNumbers.set('零', 0);
    chineseNumbers.set('一', 1);
    chineseNumbers.set('二', 2);
    chineseNumbers.set('两', 2);
    chineseNumbers.set('三', 3);
    chineseNumbers.set('四', 4);
    chineseNumbers.set('五', 5);
    chineseNumbers.set('六', 6);
    chineseNumbers.set('七', 7);
    chineseNumbers.set('八', 8);
    chineseNumbers.set('九', 9);
    chineseNumbers.set('十', 10);
    chineseNumbers.set('百', 100);

    const keys = Array.from(chineseNumbers.keys());
    for (let i = 0; i < keys.length; i++) {
      const chinese = keys[i];
      const value = chineseNumbers.get(chinese);
      if (value !== undefined && text.includes(chinese) && !numbers.includes(value)) {
        numbers.push(value);
      }
    }

    return numbers;
  }

  /**
   * 获取命令描述（用于语音反馈）
   */
  static getCommandDescription(command: ParsedVoiceCommand): string {
    if (command.type === VoiceCommandType.CONTROL_DEVICE) {
      const deviceName = VoiceCommandParser.getDeviceDisplayName(command.deviceType!);
      const actionName = command.action === 'on' ? '打开' : '关闭';
      return `${actionName}${deviceName}`;
    } else if (command.type === VoiceCommandType.START_IRRIGATION) {
      return '开始灌溉';
    } else if (command.type === VoiceCommandType.STOP_IRRIGATION) {
      return '停止灌溉';
    } else if (command.type === VoiceCommandType.SET_BRIGHTNESS) {
      return `设置补光灯亮度为${command.value}%`;
    } else if (command.type === VoiceCommandType.SET_FAN_LEVEL) {
      return `设置风扇档位为${command.value}`;
    } else {
      return '未识别的命令';
    }
  }

  /**
   * 获取设备显示名称
   */
  private static getDeviceDisplayName(type: DeviceType): string {
    if (type === DeviceType.WATER_PUMP) {
      return '水泵';
    } else if (type === DeviceType.LED) {
      return '补光灯';
    } else if (type === DeviceType.FAN) {
      return '风扇';
    } else if (type === DeviceType.VALVE) {
      return '水阀';
    } else {
      return '设备';
    }
  }

  /**
   * 获取示例命令列表（用于帮助提示）
   */
  static getExampleCommands(): string[] {
    return [
      '打开水泵',
      '关闭水泵',
      '开始灌溉',
      '停止灌溉',
      '打开补光灯',
      '关闭补光灯',
      '补光灯亮度50',
      '打开风扇',
      '关闭风扇',
      '风扇档位3'
    ];
  }
}