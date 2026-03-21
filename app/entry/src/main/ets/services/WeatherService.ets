import { HttpClient } from '../web/HttpClient'
import { WeatherData, WeatherForecast, getWeatherIcon } from '../models/WeatherData'
import { geoLocationManager } from '@kit.LocationKit'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'

const TAG = '[WeatherService]'

/**
 * API响应结构
 */
interface ApiResponse<T> {
  code: number
  message: string
  data: T
}

/**
 * 位置信息
 */
interface LocationInfo {
  latitude: number
  longitude: number
}

/**
 * 天气服务
 * 调用后端API获取天气数据
 */
export class WeatherService {
  private static instance: WeatherService
  
  // 缓存
  private cachedWeather: WeatherData | null = null
  private cacheTime: number = 0
  private readonly CACHE_DURATION = 30 * 60 * 1000  // 30分钟缓存
  
  // 错误信息
  private lastError: string = ''
  
  // 默认位置（杭州）
  private readonly DEFAULT_LOCATION: LocationInfo = {
    latitude: 30.27,    // 杭州纬度
    longitude: 120.15   // 杭州经度
  }
  
  // 位置权限
  private readonly LOCATION_PERMISSIONS: Permissions[] = [
    'ohos.permission.APPROXIMATELY_LOCATION',
    'ohos.permission.LOCATION'
  ]
  
  private constructor() {}
  
  static getInstance(): WeatherService {
    if (!WeatherService.instance) {
      WeatherService.instance = new WeatherService()
    }
    return WeatherService.instance
  }
  
  /**
   * 获取当前天气（自动获取位置，失败则使用杭州）
   */
  async getCurrentWeather(): Promise<WeatherData | null> {
    // 检查缓存
    const now = Date.now()
    if (this.cachedWeather && (now - this.cacheTime) < this.CACHE_DURATION) {
      console.info(TAG, '使用缓存天气数据')
      return this.cachedWeather
    }
    
    try {
      this.lastError = ''
      
      let location: LocationInfo = this.DEFAULT_LOCATION  // 默认使用杭州
      let useDefaultLocation = false
      
      // 1. 尝试获取位置权限
      const hasPermission = await this.requestLocationPermission()
      
      if (hasPermission) {
        // 2. 尝试获取当前位置
        const currentLocation = await this.getCurrentLocation()
        if (currentLocation) {
          location = currentLocation
          console.info(TAG, `获取位置成功: ${location.latitude}, ${location.longitude}`)
        } else {
          useDefaultLocation = true
          console.info(TAG, 'GPS定位失败，使用默认位置（杭州）')
        }
      } else {
        useDefaultLocation = true
        console.info(TAG, '位置权限未授权，使用默认位置（杭州）')
      }
      
      // 3. 根据位置获取天气
      const url = `/api/weather/current?latitude=${location.latitude}&longitude=${location.longitude}`
      const response = await HttpClient.get<ApiResponse<WeatherData>>(url)
      
      if (response.code === 200 && response.data) {
        // 如果使用默认位置，在数据中标记
        if (useDefaultLocation && response.data) {
          response.data.location = '杭州'
        }
        this.cachedWeather = response.data
        this.cacheTime = now
        return response.data
      }
      
      this.lastError = response.message || '获取天气失败'
      console.error(TAG, '获取天气失败:', this.lastError)
      return null
    } catch (error) {
      const errMsg = error instanceof Error ? error.message : String(error)
      this.lastError = '网络连接失败，无法获取天气信息'
      console.error(TAG, '获取天气失败:', errMsg)
      return null
    }
  }
  
  /**
   * 请求位置权限
   */
  private async requestLocationPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const context = getContext(this) as common.UIAbilityContext
      
      // 检查是否已有权限
      for (const permission of this.LOCATION_PERMISSIONS) {
        const grantStatus = await atManager.checkAccessToken(
          context.applicationInfo.accessTokenId,
          permission
        )
        
        if (grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
          console.info(TAG, `已有权限: ${permission}`)
          return true
        }
      }
      
      // 请求权限
      console.info(TAG, '请求位置权限...')
      const result = await atManager.requestPermissionsFromUser(
        context, 
        this.LOCATION_PERMISSIONS
      )
      
      // 检查授权结果
      for (let i = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] === 0) {
          console.info(TAG, '位置权限授权成功')
          return true
        }
      }
      
      console.error(TAG, '位置权限授权失败')
      return false
    } catch (error) {
      const err = error as BusinessError
      console.error(TAG, `权限请求异常: ${err.message}`)
      return false
    }
  }
  
  /**
   * 获取当前位置
   */
  private async getCurrentLocation(): Promise<LocationInfo | null> {
    try {
      // HarmonyOS 单次定位
      // 使用默认配置获取位置
      const location = await geoLocationManager.getCurrentLocation()
      
      if (location && location.latitude !== undefined && location.longitude !== undefined) {
        console.info(TAG, `定位成功: ${location.latitude}, ${location.longitude}`)
        const info: LocationInfo = {
          latitude: location.latitude,
          longitude: location.longitude
        }
        return info
      }
      
      return null
    } catch (error) {
      const err = error as BusinessError
      console.error(TAG, `获取位置失败: code=${err.code}, message=${err.message}`)
      return null
    }
  }
  
  /**
   * 获取最后的错误信息
   */
  getLastError(): string {
    return this.lastError
  }
  
  /**
   * 清除缓存
   */
  clearCache(): void {
    this.cachedWeather = null
    this.cacheTime = 0
    this.lastError = ''
  }
}