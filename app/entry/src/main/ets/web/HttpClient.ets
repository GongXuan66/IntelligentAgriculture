import http from '@ohos.net.http'

/**
 * HTTP客户端配置
 */
export class HttpConfig {
  // 服务器地址配置说明:
  // - DevEco 预览器: http://localhost:8123
  // - 本地模拟器: 使用电脑实际IP地址
  // - 真机调试: http://电脑局域网IP:8123
  
  // 当前配置: 使用实际IP地址
  static readonly BASE_URL: string = 'http://10.150.211.229:8123'
  static readonly TIMEOUT: number = 60000
}

/**
 * HTTP请求工具类
 */
export class HttpClient {
  /**
   * GET请求
   */
  static async get<T>(url: string): Promise<T> {
    let httpRequest = http.createHttp()
    let fullUrl = `${HttpConfig.BASE_URL}${url}`
    console.info(`[HttpClient] GET请求: ${fullUrl}`)
    
    let response: http.HttpResponse
    try {
      response = await httpRequest.request(
        fullUrl,
        {
          method: http.RequestMethod.GET,
          connectTimeout: HttpConfig.TIMEOUT,
          readTimeout: HttpConfig.TIMEOUT,
          header: {
            'Content-Type': 'application/json'
          }
        }
      )
    } catch (err) {
      httpRequest.destroy()
      let errorMsg = err instanceof Error ? err.message : String(err)
      console.error(`[HttpClient] 网络请求失败: ${errorMsg}`)
      throw new Error(`网络请求失败: ${errorMsg}`)
    }
    
    httpRequest.destroy()
    console.info(`[HttpClient] 响应码: ${response.responseCode}`)
    
    if (response.responseCode === 200) {
      let result: T = JSON.parse(response.result as string) as T
      console.info(`[HttpClient] 请求成功`)
      return result
    } else {
      console.error(`[HttpClient] HTTP错误: ${response.responseCode}`)
      throw new Error(`HTTP错误: ${response.responseCode}`)
    }
  }

  /**
   * POST请求
   */
  static async post<T>(url: string, data: object): Promise<T> {
    let httpRequest = http.createHttp()
    let fullUrl = `${HttpConfig.BASE_URL}${url}`
    console.info(`[HttpClient] POST请求: ${fullUrl}`)
    
    let response: http.HttpResponse
    try {
      response = await httpRequest.request(
        fullUrl,
        {
          method: http.RequestMethod.POST,
          connectTimeout: HttpConfig.TIMEOUT,
          readTimeout: HttpConfig.TIMEOUT,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(data)
        }
      )
    } catch (err) {
      httpRequest.destroy()
      let errorMsg = err instanceof Error ? err.message : String(err)
      console.error(`[HttpClient] 网络请求失败: ${errorMsg}`)
      throw new Error(`网络请求失败: ${errorMsg}`)
    }
    
    httpRequest.destroy()
    console.info(`[HttpClient] 响应码: ${response.responseCode}`)
    
    if (response.responseCode === 200) {
      let result: T = JSON.parse(response.result as string) as T
      console.info(`[HttpClient] 请求成功`)
      return result
    } else {
      console.error(`[HttpClient] HTTP错误: ${response.responseCode}`)
      throw new Error(`HTTP错误: ${response.responseCode}`)
    }
  }

  /**
   * PUT请求
   */
  static async put<T>(url: string, data: object): Promise<T> {
    let httpRequest = http.createHttp()
    let fullUrl = `${HttpConfig.BASE_URL}${url}`
    console.info(`[HttpClient] PUT请求: ${fullUrl}`)
    
    let response: http.HttpResponse
    try {
      response = await httpRequest.request(
        fullUrl,
        {
          method: http.RequestMethod.PUT,
          connectTimeout: HttpConfig.TIMEOUT,
          readTimeout: HttpConfig.TIMEOUT,
          header: {
            'Content-Type': 'application/json'
          },
          extraData: JSON.stringify(data)
        }
      )
    } catch (err) {
      httpRequest.destroy()
      let errorMsg = err instanceof Error ? err.message : String(err)
      console.error(`[HttpClient] 网络请求失败: ${errorMsg}`)
      throw new Error(`网络请求失败: ${errorMsg}`)
    }
    
    httpRequest.destroy()
    console.info(`[HttpClient] 响应码: ${response.responseCode}`)
    
    if (response.responseCode === 200) {
      let result: T = JSON.parse(response.result as string) as T
      console.info(`[HttpClient] 请求成功`)
      return result
    } else {
      console.error(`[HttpClient] HTTP错误: ${response.responseCode}`)
      throw new Error(`HTTP错误: ${response.responseCode}`)
    }
  }
}