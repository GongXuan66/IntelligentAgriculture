import http from '@ohos.net.http'

/**
 * HTTP客户端配置
 */
export class HttpConfig {
  // 服务器地址 - 修改为你的电脑IP地址
  // 本机测试可用: http://127.0.0.1:8080 或 http://localhost:8080
  // 真机测试需用电脑局域网IP: http://192.168.x.x:8080
  //previewer
  static readonly BASE_URL: string = 'http://localhost:8123'
  //模拟器
  //static readonly BASE_URL: string = '10.252.147.68:8123'
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
    try {
      let response = await httpRequest.request(
        `${HttpConfig.BASE_URL}${url}`,
        {
          method: http.RequestMethod.GET,
          connectTimeout: HttpConfig.TIMEOUT,
          readTimeout: HttpConfig.TIMEOUT,
          header: {
            'Content-Type': 'application/json'
          }
        }
      )
      
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T
      } else {
        throw new Error(`HTTP Error: ${response.responseCode}`)
      }
    } finally {
      httpRequest.destroy()
    }
  }

  /**
   * POST请求
   */
  static async post<T>(url: string, data: object): Promise<T> {
    let httpRequest = http.createHttp()
    try {
      let response = await httpRequest.request(
        `${HttpConfig.BASE_URL}${url}`,
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
      
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T
      } else {
        throw new Error(`HTTP Error: ${response.responseCode}`)
      }
    } finally {
      httpRequest.destroy()
    }
  }

  /**
   * PUT请求
   */
  static async put<T>(url: string, data: object): Promise<T> {
    let httpRequest = http.createHttp()
    try {
      let response = await httpRequest.request(
        `${HttpConfig.BASE_URL}${url}`,
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
      
      if (response.responseCode === 200) {
        return JSON.parse(response.result as string) as T
      } else {
        throw new Error(`HTTP Error: ${response.responseCode}`)
      }
    } finally {
      httpRequest.destroy()
    }
  }
}