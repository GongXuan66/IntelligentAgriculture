import preferences from '@ohos.data.preferences'
import common from '@ohos.app.ability.common'
import { EnvironmentThreshold } from '../models/EnvironmentData'
import { AlarmConfig } from '../models/Alarm'
import { IrrigationConfig } from '../models/Irrigation'
import { Device, DeviceStatus, DeviceType } from '../models/Device'

/**
 * 存储键名常量
 */
export class StorageKeys {
  // 用户配置
  static readonly ENVIRONMENT_THRESHOLD = 'environment_threshold'
  static readonly ALARM_CONFIG = 'alarm_config'
  static readonly IRRIGATION_CONFIG = 'irrigation_config'
  
  // 会话状态
  static readonly AUTH_TOKEN = 'auth_token'
  static readonly CURRENT_POINT_ID = 'current_point_id'
  static readonly THEME_MODE = 'theme_mode'
  static readonly LANGUAGE = 'language'
  
  // 缓存数据
  static readonly DEVICE_LIST_CACHE = 'device_list_cache'
  static readonly RECENT_ENV_DATA = 'recent_env_data'
  static readonly UNREAD_ALARM_COUNT = 'unread_alarm_count'
  static readonly LAST_SYNC_TIME = 'last_sync_time'
  
  // 离线队列
  static readonly OFFLINE_COMMAND_QUEUE = 'offline_command_queue'
  static readonly OFFLINE_LOG_QUEUE = 'offline_log_queue'
  
  // AI对话历史
  static readonly AI_CHAT_HISTORY = 'ai_chat_history'
  // AI会话列表
  static readonly AI_SESSION_LIST = 'ai_session_list'
  // 当前会话ID
  static readonly AI_CURRENT_SESSION_ID = 'ai_current_session_id'
}

/**
 * 离线命令
 */
export interface OfflineCommand {
  id: string
  deviceId: string
  command: string
  timestamp: number
  synced: boolean
}

/**
 * 离线日志
 */
export interface OfflineLog {
  id: string
  type: 'irrigation' | 'alarm' | 'device'
  data: Record<string, Object>
  timestamp: number
  synced: boolean
}

/**
 * 设备缓存数据
 */
export interface DeviceCache {
  devices: Device[]
  cachedAt: number
}
/**
 * 环境数据缓存
 */
export interface EnvDataCache {
  data: Record<string, Object>
  cachedAt: number
}

/**
 * 存储统计信息
 */
export interface StorageStats {
  hasThreshold: boolean
  hasAlarmConfig: boolean
  hasIrrigationConfig: boolean
  pendingCommands: number
  pendingLogs: number
  lastSyncTime: string
}

/**
 * AI对话历史记录项
 */
export interface ChatHistoryItem {
  role: string      // 'user' or 'assistant'
  content: string
  time: string
}

/**
 * AI会话
 */
export interface ChatSession {
  id: string
  title: string
  messages: ChatHistoryItem[]
  createdAt: string
  updatedAt: string
}

/**
 * 本地存储服务
 * 使用 HarmonyOS Preferences API 实现数据持久化
 */
export class PreferencesService {
  private static instance: PreferencesService
  private preferences: preferences.Preferences | null = null
  private context: common.UIAbilityContext | null = null
  private readonly STORE_NAME = 'intelligent_agriculture_prefs'
  
  // 默认值
  private readonly DEFAULT_THRESHOLD: EnvironmentThreshold = {
    temperatureMax: 35,
    temperatureMin: 10,
    humidityMax: 80,
    humidityMin: 30,
    lightMin: 300,
    co2Max: 1000,
    soilMoistureMin: 40
  }
  
  private readonly DEFAULT_ALARM_CONFIG: AlarmConfig = {
    enableTemperatureAlarm: true,
    enableHumidityAlarm: true,
    enableLightAlarm: true,
    enableCo2Alarm: true,
    enableSoilMoistureAlarm: true,
    enableDeviceAlarm: true
  }
  
  private readonly DEFAULT_IRRIGATION_CONFIG: IrrigationConfig = {
    autoMode: true,
    moistureThreshold: 40,
    irrigationDuration: 30,
    minInterval: 3600
  }

  private constructor() {}

  /**
   * 获取单例实例
   */
  static getInstance(): PreferencesService {
    if (!PreferencesService.instance) {
      PreferencesService.instance = new PreferencesService()
    }
    return PreferencesService.instance
  }

  /**
   * 初始化 Preferences
   * 必须在 UIAbility 的 onCreate 或页面加载时调用
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.context = context
      this.preferences = await preferences.getPreferences(context, this.STORE_NAME)
      console.log('[PreferencesService] 初始化成功')
    } catch (error) {
      console.error('[PreferencesService] 初始化失败:', error)
      throw new Error(`初始化失败: ${error}`)
    }
  }

  /**
   * 确保已初始化
   */
  private ensureInitialized(): void {
    if (!this.preferences) {
      throw new Error('[PreferencesService] 未初始化，请先调用 init() 方法')
    }
  }

  // ==================== 用户配置 ====================

  /**
   * 获取环境阈值配置
   */
  async getEnvironmentThreshold(): Promise<EnvironmentThreshold> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.ENVIRONMENT_THRESHOLD, '') as string
      if (jsonStr) {
        return JSON.parse(jsonStr) as EnvironmentThreshold
      }
      return this.DEFAULT_THRESHOLD
    } catch (error) {
      console.error('[PreferencesService] 获取环境阈值配置失败:', error)
      return this.DEFAULT_THRESHOLD
    }
  }

  /**
   * 保存环境阈值配置
   */
  async setEnvironmentThreshold(config: EnvironmentThreshold): Promise<void> {
    this.ensureInitialized()
    try {
      await this.preferences!.put(StorageKeys.ENVIRONMENT_THRESHOLD, JSON.stringify(config))
      await this.preferences!.flush()
      console.log('[PreferencesService] 环境阈值配置已保存')
    } catch (error) {
      console.error('[PreferencesService] 保存环境阈值配置失败:', error)
      throw new Error(`保存环境阈值配置失败: ${error}`)
    }
  }

  /**
   * 获取报警配置
   */
  async getAlarmConfig(): Promise<AlarmConfig> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.ALARM_CONFIG, '') as string
      if (jsonStr) {
        return JSON.parse(jsonStr) as AlarmConfig
      }
      return this.DEFAULT_ALARM_CONFIG
    } catch (error) {
      console.error('[PreferencesService] 获取报警配置失败:', error)
      return this.DEFAULT_ALARM_CONFIG
    }
  }

  /**
   * 保存报警配置
   */
  async setAlarmConfig(config: AlarmConfig): Promise<void> {
    this.ensureInitialized()
    try {
      await this.preferences!.put(StorageKeys.ALARM_CONFIG, JSON.stringify(config))
      await this.preferences!.flush()
      console.log('[PreferencesService] 报警配置已保存')
    } catch (error) {
      console.error('[PreferencesService] 保存报警配置失败:', error)
      throw new Error(`保存报警配置失败: ${error}`)
    }
  }

  /**
   * 获取灌溉配置
   */
  async getIrrigationConfig(): Promise<IrrigationConfig> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.IRRIGATION_CONFIG, '') as string
      if (jsonStr) {
        return JSON.parse(jsonStr) as IrrigationConfig
      }
      return this.DEFAULT_IRRIGATION_CONFIG
    } catch (error) {
      console.error('[PreferencesService] 获取灌溉配置失败:', error)
      return this.DEFAULT_IRRIGATION_CONFIG
    }
  }

  /**
   * 保存灌溉配置
   */
  async setIrrigationConfig(config: IrrigationConfig): Promise<void> {
    this.ensureInitialized()
    try {
      await this.preferences!.put(StorageKeys.IRRIGATION_CONFIG, JSON.stringify(config))
      await this.preferences!.flush()
      console.log('[PreferencesService] 灌溉配置已保存')
    } catch (error) {
      console.error('[PreferencesService] 保存灌溉配置失败:', error)
      throw new Error(`保存灌溉配置失败: ${error}`)
    }
  }

  // ==================== 会话状态 ====================

  /**
   * 获取认证 Token
   */
  async getAuthToken(): Promise<string> {
    this.ensureInitialized()
    return await this.preferences!.get(StorageKeys.AUTH_TOKEN, '') as string
  }

  /**
   * 保存认证 Token
   */
  async setAuthToken(token: string): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.AUTH_TOKEN, token)
    await this.preferences!.flush()
  }

  /**
   * 清除认证 Token
   */
  async clearAuthToken(): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.delete(StorageKeys.AUTH_TOKEN)
    await this.preferences!.flush()
  }

  /**
   * 获取当前检测点 ID
   */
  async getCurrentPointId(): Promise<number> {
    this.ensureInitialized()
    return await this.preferences!.get(StorageKeys.CURRENT_POINT_ID, 1) as number
  }

  /**
   * 保存当前检测点 ID
   */
  async setCurrentPointId(pointId: number): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.CURRENT_POINT_ID, pointId)
    await this.preferences!.flush()
  }

  /**
   * 获取主题模式 (0: 跟随系统, 1: 浅色, 2: 深色)
   */
  async getThemeMode(): Promise<number> {
    this.ensureInitialized()
    return await this.preferences!.get(StorageKeys.THEME_MODE, 0) as number
  }

  /**
   * 保存主题模式
   */
  async setThemeMode(mode: number): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.THEME_MODE, mode)
    await this.preferences!.flush()
  }

  /**
   * 获取语言设置
   */
  async getLanguage(): Promise<string> {
    this.ensureInitialized()
    return await this.preferences!.get(StorageKeys.LANGUAGE, 'zh') as string
  }

  /**
   * 保存语言设置
   */
  async setLanguage(lang: string): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.LANGUAGE, lang)
    await this.preferences!.flush()
  }

  // ==================== 缓存数据 ====================

  /**
   * 获取设备列表缓存
   */
  async getDeviceListCache(): Promise<DeviceCache | null> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.DEVICE_LIST_CACHE, '') as string
      if (jsonStr) {
        return JSON.parse(jsonStr) as DeviceCache
      }
      return null
    } catch (error) {
      console.error('[PreferencesService] 获取设备缓存失败:', error)
      return null
    }
  }

  /**
   * 保存设备列表缓存
   */
  async setDeviceListCache(devices: Device[]): Promise<void> {
    this.ensureInitialized()
    try {
      const cache: DeviceCache = {
        devices: devices,
        cachedAt: Date.now()
      }
      await this.preferences!.put(StorageKeys.DEVICE_LIST_CACHE, JSON.stringify(cache))
      await this.preferences!.flush()
    } catch (error) {
      console.error('[PreferencesService] 保存设备缓存失败:', error)
    }
  }

  /**
   * 获取最近环境数据缓存
   */
  async getRecentEnvDataCache(): Promise<EnvDataCache | null> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.RECENT_ENV_DATA, '') as string
      if (jsonStr) {
        return JSON.parse(jsonStr) as EnvDataCache
      }
      return null
    } catch (error) {
      console.error('[PreferencesService] 获取环境数据缓存失败:', error)
      return null
    }
  }

  /**
   * 保存最近环境数据缓存
   */
  async setRecentEnvDataCache(data: Record<string, Object>): Promise<void> {
    this.ensureInitialized()
    try {
      const cache: EnvDataCache = {
        data: data,
        cachedAt: Date.now()
      }
      await this.preferences!.put(StorageKeys.RECENT_ENV_DATA, JSON.stringify(cache))
      await this.preferences!.flush()
    } catch (error) {
      console.error('[PreferencesService] 保存环境数据缓存失败:', error)
    }
  }

  /**
   * 获取未读报警数量
   */
  async getUnreadAlarmCount(): Promise<number> {
    this.ensureInitialized()
    return await this.preferences!.get(StorageKeys.UNREAD_ALARM_COUNT, 0) as number
  }

  /**
   * 保存未读报警数量
   */
  async setUnreadAlarmCount(count: number): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.UNREAD_ALARM_COUNT, count)
    await this.preferences!.flush()
  }

  /**
   * 获取最后同步时间
   */
  async getLastSyncTime(): Promise<number> {
    this.ensureInitialized()
    return await this.preferences!.get(StorageKeys.LAST_SYNC_TIME, 0) as number
  }

  /**
   * 保存最后同步时间
   */
  async setLastSyncTime(time: number): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.LAST_SYNC_TIME, time)
    await this.preferences!.flush()
  }

  // ==================== 离线队列 ====================

  /**
   * 获取离线命令队列
   */
  async getOfflineCommandQueue(): Promise<OfflineCommand[]> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.OFFLINE_COMMAND_QUEUE, '[]') as string
      return JSON.parse(jsonStr) as OfflineCommand[]
    } catch (error) {
      console.error('[PreferencesService] 获取离线命令队列失败:', error)
      return []
    }
  }

  /**
   * 添加离线命令
   */
  async addOfflineCommand(deviceId: string, command: string): Promise<OfflineCommand> {
    this.ensureInitialized()
    const queue = await this.getOfflineCommandQueue()
    const offlineCmd: OfflineCommand = {
      id: `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      deviceId: deviceId,
      command: command,
      timestamp: Date.now(),
      synced: false
    }
    queue.push(offlineCmd)
    await this.preferences!.put(StorageKeys.OFFLINE_COMMAND_QUEUE, JSON.stringify(queue))
    await this.preferences!.flush()
    console.log('[PreferencesService] 离线命令已添加:', offlineCmd.id)
    return offlineCmd
  }

  /**
   * 标记命令已同步
   */
  async markCommandSynced(commandId: string): Promise<void> {
    this.ensureInitialized()
    const queue = await this.getOfflineCommandQueue()
    const index = queue.findIndex(cmd => cmd.id === commandId)
    if (index !== -1) {
      queue[index].synced = true
      await this.preferences!.put(StorageKeys.OFFLINE_COMMAND_QUEUE, JSON.stringify(queue))
      await this.preferences!.flush()
    }
  }

  /**
   * 移除已同步的命令
   */
  async removeSyncedCommands(): Promise<void> {
    this.ensureInitialized()
    const queue = await this.getOfflineCommandQueue()
    const unsynced = queue.filter(cmd => !cmd.synced)
    await this.preferences!.put(StorageKeys.OFFLINE_COMMAND_QUEUE, JSON.stringify(unsynced))
    await this.preferences!.flush()
    console.log('[PreferencesService] 已移除同步的命令，剩余:', unsynced.length)
  }

  /**
   * 获取待同步的命令数量
   */
  async getPendingCommandCount(): Promise<number> {
    const queue = await this.getOfflineCommandQueue()
    return queue.filter(cmd => !cmd.synced).length
  }

  /**
   * 获取离线日志队列
   */
  async getOfflineLogQueue(): Promise<OfflineLog[]> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.OFFLINE_LOG_QUEUE, '[]') as string
      return JSON.parse(jsonStr) as OfflineLog[]
    } catch (error) {
      console.error('[PreferencesService] 获取离线日志队列失败:', error)
      return []
    }
  }

  /**
   * 添加离线日志
   */
  async addOfflineLog(type: 'irrigation' | 'alarm' | 'device', data: Record<string, Object>): Promise<OfflineLog> {
    this.ensureInitialized()
    const queue = await this.getOfflineLogQueue()
    const log: OfflineLog = {
      id: `${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: type,
      data: data,
      timestamp: Date.now(),
      synced: false
    }
    queue.push(log)
    await this.preferences!.put(StorageKeys.OFFLINE_LOG_QUEUE, JSON.stringify(queue))
    await this.preferences!.flush()
    console.log('[PreferencesService] 离线日志已添加:', log.id)
    return log
  }

  /**
   * 清除所有离线数据
   */
  async clearOfflineData(): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.delete(StorageKeys.OFFLINE_COMMAND_QUEUE)
    await this.preferences!.delete(StorageKeys.OFFLINE_LOG_QUEUE)
    await this.preferences!.flush()
    console.log('[PreferencesService] 离线数据已清除')
  }

  // ==================== 工具方法 ====================

  /**
   * 清除所有数据
   */
  async clearAll(): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.clear()
    await this.preferences!.flush()
    console.log('[PreferencesService] 所有数据已清除')
  }

  // ==================== AI会话管理 ====================

  /**
   * 生成唯一会话ID
   */
  private generateSessionId(): string {
    return 'session_' + Date.now() + '_' + Math.random().toString(36).substring(2, 9)
  }

  /**
   * 获取会话列表
   */
  async getAISessionList(): Promise<ChatSession[]> {
    this.ensureInitialized()
    try {
      const jsonStr = await this.preferences!.get(StorageKeys.AI_SESSION_LIST, '[]') as string
      return JSON.parse(jsonStr) as ChatSession[]
    } catch (error) {
      console.error('[PreferencesService] 获取会话列表失败:', error)
      return []
    }
  }

  /**
   * 保存会话列表
   */
  async setAISessionList(sessions: ChatSession[]): Promise<void> {
    this.ensureInitialized()
    try {
      await this.preferences!.put(StorageKeys.AI_SESSION_LIST, JSON.stringify(sessions))
      await this.preferences!.flush()
    } catch (error) {
      console.error('[PreferencesService] 保存会话列表失败:', error)
    }
  }

  /**
   * 获取当前会话ID
   */
  async getCurrentSessionId(): Promise<string> {
    this.ensureInitialized()
    try {
      const id = await this.preferences!.get(StorageKeys.AI_CURRENT_SESSION_ID, '') as string
      return id
    } catch (error) {
      console.error('[PreferencesService] 获取当前会话ID失败:', error)
      return ''
    }
  }

  /**
   * 设置当前会话ID
   */
  async setCurrentSessionId(sessionId: string): Promise<void> {
    this.ensureInitialized()
    try {
      await this.preferences!.put(StorageKeys.AI_CURRENT_SESSION_ID, sessionId)
      await this.preferences!.flush()
    } catch (error) {
      console.error('[PreferencesService] 设置当前会话ID失败:', error)
    }
  }

  /**
   * 创建新会话
   */
  async createAISession(): Promise<ChatSession> {
    const sessions = await this.getAISessionList()
    const now = new Date().toISOString()
    const newSession: ChatSession = {
      id: this.generateSessionId(),
      title: '新对话',
      messages: [],
      createdAt: now,
      updatedAt: now
    }
    sessions.unshift(newSession)
    await this.setAISessionList(sessions)
    await this.setCurrentSessionId(newSession.id)
    return newSession
  }

  /**
   * 获取指定会话
   */
  async getAISession(sessionId: string): Promise<ChatSession | null> {
    const sessions = await this.getAISessionList()
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].id === sessionId) {
        return sessions[i]
      }
    }
    return null
  }

  /**
   * 获取当前会话（如果不存在则创建）
   */
  async getCurrentSession(): Promise<ChatSession> {
    const currentId = await this.getCurrentSessionId()
    if (currentId) {
      const session = await this.getAISession(currentId)
      if (session) {
        return session
      }
    }
    // 没有当前会话，创建新会话
    return await this.createAISession()
  }

  /**
   * 更新会话
   */
  async updateAISession(session: ChatSession): Promise<void> {
    const sessions = await this.getAISessionList()
    for (let i = 0; i < sessions.length; i++) {
      if (sessions[i].id === session.id) {
        sessions[i] = session
        break
      }
    }
    await this.setAISessionList(sessions)
  }

  /**
   * 添加消息到当前会话
   */
  async addAIMessage(role: string, content: string): Promise<void> {
    const session = await this.getCurrentSession()
    const now = new Date().toISOString()
    const item: ChatHistoryItem = {
      role: role,
      content: content,
      time: now
    }
    session.messages.push(item)
    session.updatedAt = now
    
    // 自动生成标题（取第一条用户消息的前20个字符）
    if (session.title === '新对话' && role === 'user') {
      session.title = content.length > 20 ? content.substring(0, 20) + '...' : content
    }
    
    await this.updateAISession(session)
  }

  /**
   * 删除会话
   */
  async deleteAISession(sessionId: string): Promise<void> {
    const sessions = await this.getAISessionList()
    const filtered = sessions.filter(s => s.id !== sessionId)
    await this.setAISessionList(filtered)
    
    // 如果删除的是当前会话，清空当前会话ID
    const currentId = await this.getCurrentSessionId()
    if (currentId === sessionId) {
      await this.setCurrentSessionId('')
    }
  }

  /**
   * 清空所有会话
   */
  async clearAllAISessions(): Promise<void> {
    this.ensureInitialized()
    await this.preferences!.put(StorageKeys.AI_SESSION_LIST, '[]')
    await this.preferences!.put(StorageKeys.AI_CURRENT_SESSION_ID, '')
    await this.preferences!.flush()
    console.log('[PreferencesService] 所有AI会话已清空')
  }

  // ==================== 兼容旧API ====================

  /**
   * 获取AI对话历史（兼容旧API）
   * @param maxCount 最大返回数量，默认50条
   */
  async getAIChatHistory(maxCount: number = 50): Promise<ChatHistoryItem[]> {
    const session = await this.getCurrentSession()
    const messages = session.messages
    if (messages.length > maxCount) {
      return messages.slice(-maxCount)
    }
    return messages
  }

  /**
   * 保存AI对话历史（兼容旧API）
   */
  async setAIChatHistory(history: ChatHistoryItem[]): Promise<void> {
    const session = await this.getCurrentSession()
    session.messages = history
    session.updatedAt = new Date().toISOString()
    await this.updateAISession(session)
  }

  /**
   * 添加单条对话记录（兼容旧API）
   */
  async addAIChatMessage(role: string, content: string): Promise<void> {
    await this.addAIMessage(role, content)
  }

  /**
   * 清空AI对话历史（兼容旧API）
   */
  async clearAIChatHistory(): Promise<void> {
    const session = await this.getCurrentSession()
    session.messages = []
    session.updatedAt = new Date().toISOString()
    await this.updateAISession(session)
  }

  /**
   * 检查缓存是否过期
   * @param cachedAt 缓存时间戳
   * @param maxAge 最大有效期（毫秒）
   */
  isCacheExpired(cachedAt: number, maxAge: number): boolean {
    return Date.now() - cachedAt > maxAge
  }
  /**
   * 获取存储统计信息
   */
  async getStorageStats(): Promise<StorageStats> {
    const threshold = await this.getEnvironmentThreshold()
    const alarmConfig = await this.getAlarmConfig()
    const irrigationConfig = await this.getIrrigationConfig()
    const pendingCommands = await this.getPendingCommandCount()
    const offlineLogs = (await this.getOfflineLogQueue()).filter(log => !log.synced).length
    const lastSync = await this.getLastSyncTime()
    
    return {
      hasThreshold: !!threshold,
      hasAlarmConfig: !!alarmConfig,
      hasIrrigationConfig: !!irrigationConfig,
      pendingCommands: pendingCommands,
      pendingLogs: offlineLogs,
      lastSyncTime: lastSync > 0 ? new Date(lastSync).toLocaleString() : '从未同步'
    }
  }
}

/**
 * 全局实例快捷访问
 */
export const prefsService = PreferencesService.getInstance()
