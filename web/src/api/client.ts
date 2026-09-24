import { env } from '../config/env'
import type { ApiResponse } from './types'

const API_BASE = env.apiBaseUrl.replace(/\/$/, '')

export class ApiError extends Error {
  constructor(
    message: string,
    public code?: number,
  ) {
    super(message)
  }
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const resp = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init,
  })
  if (!resp.ok) {
    throw new ApiError(`请求失败 (${resp.status})`, resp.status)
  }
  const body = (await resp.json()) as ApiResponse<T>
  if (body.code !== 0 && body.code !== 200) {
    throw new ApiError(body.message || '接口返回错误', body.code)
  }
  return body.data
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, data?: unknown) =>
    request<T>(path, { method: 'POST', body: JSON.stringify(data ?? {}) }),
  put: <T>(path: string, data?: unknown) =>
    request<T>(path, { method: 'PUT', body: JSON.stringify(data ?? {}) }),
  delete: <T>(path: string) => request<T>(path, { method: 'DELETE' }),
}
