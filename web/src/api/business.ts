import { api } from './client'
import type {
  Alarm,
  Device,
  EnvironmentData,
  IrrigationLog,
  IrrigationStrategy,
  MonitorPoint,
  MoisturePrediction,
  SmartIrrigationPlan,
} from './types'

/** IA-server 业务接口封装 */

export function getMonitorPoints() {
  return api.get<MonitorPoint[]>('/point/list')
}

export function getDevices() {
  return api.get<Device[]>('/device/list')
}

export function controlDevice(deviceCode: string, command: 'on' | 'off') {
  return api.post<Device>('/device/control', { deviceCode, command })
}

export function getCurrentEnvironment(pointId: number) {
  return api.get<EnvironmentData>(`/environment?pointId=${pointId}`)
}

export function getEnvironmentHistory(pointId: number, limit = 48) {
  return api.get<EnvironmentData[]>(`/environment/history?pointId=${pointId}&limit=${limit}`)
}

export function getAlarms() {
  return api.get<Alarm[]>('/alarm/list')
}

export function getUnprocessedAlarmCount() {
  return api.get<number>('/alarm/unprocessed/count')
}

export function handleAlarm(id: number, remark?: string) {
  return api.put<Alarm>(`/alarm/${id}/handle`, { remark })
}

export function getIrrigationLogs(pointId?: number) {
  const query = pointId ? `?pointId=${pointId}` : ''
  return api.get<IrrigationLog[]>(`/irrigation/logs${query}`)
}

export function getLatestIrrigation(pointId: number) {
  return api.get<IrrigationLog>(`/irrigation/latest?pointId=${pointId}`)
}

export function getIrrigationTotal(pointId: number) {
  return api.get<number>(`/irrigation/total?pointId=${pointId}`)
}

export function startIrrigation(pointId: number, duration = 60, mode = 1) {
  return api.post<IrrigationLog>('/irrigation/start', { pointId, duration, mode })
}

export function stopIrrigation(logId: number) {
  return api.post<IrrigationLog>('/irrigation/stop', { logId })
}

export function getMoisturePrediction(pointId: number) {
  return api.get<MoisturePrediction>(`/smart-irrigation/predict?pointId=${pointId}`)
}

export function getSmartPlan(pointId: number) {
  return api.post<SmartIrrigationPlan>(`/smart-irrigation/plan?pointId=${pointId}`)
}

export function getIrrigationStrategy(pointId: number) {
  return api.get<IrrigationStrategy>(`/smart-irrigation/strategy?pointId=${pointId}`)
}
