import type { ReactNode } from 'react';
import { Tag } from 'antd';

/** 设备状态：0 离线 / 1 在线 / 2 工作中 / 3 故障 */
export const DEVICE_STATUS_MAP: Record<number, { text: string; color: string }> = {
  0: { text: '离线', color: 'default' },
  1: { text: '在线', color: 'green' },
  2: { text: '工作中', color: 'processing' },
  3: { text: '故障', color: 'error' },
};

/** 告警状态：0 未处理 / 1 已处理 / 2 已忽略 */
export const ALARM_STATUS_MAP: Record<number, { text: string; color: string }> = {
  0: { text: '未处理', color: 'error' },
  1: { text: '已处理', color: 'success' },
  2: { text: '已忽略', color: 'default' },
};

/** 告警级别 */
export const ALARM_LEVEL_MAP: Record<number, { text: string; color: string }> = {
  1: { text: '低', color: 'default' },
  2: { text: '中', color: 'warning' },
  3: { text: '高', color: 'error' },
};

/** 灌溉模式 */
export const IRRIGATION_MODE_MAP: Record<number, string> = {
  0: '自动',
  1: '手动',
  2: '智能',
};

export const DECISION_TYPE_MAP: Record<string, string> = {
  predictive: '预测式灌溉',
  adaptive: '自适应灌溉',
  stage_based: '生育期灌溉',
  standard: '常规灌溉',
};

export const TREND_MAP: Record<string, { text: string; color: string }> = {
  rising: { text: '上升', color: 'green' },
  falling: { text: '下降', color: 'red' },
  stable: { text: '平稳', color: 'default' },
};

export function renderStatusTag(
  map: Record<number, { text: string; color: string }>,
  value?: number,
): ReactNode {
  const item = value !== undefined ? map[value] : undefined;
  return <Tag color={item?.color || 'default'}>{item?.text ?? '未知'}</Tag>;
}

/** 简单的中文工具名映射，用于 Agent 轨迹展示 */
export const TOOL_NAME_MAP: Record<string, string> = {
  get_all_devices: '查询全部设备',
  get_devices_by_point_id: '按监测点查询设备',
  get_device_by_device_code: '查询设备实时状态',
  control_device: '控制设备开关',
  get_current_environment: '查询当前环境数据',
  get_history_environment: '查询历史环境数据',
  get_history_environment_range: '按时间范围查询环境数据',
  get_irrigation_logs: '查询灌溉记录',
  get_latest_irrigation_log: '查询最近灌溉记录',
  get_irrigation_total: '查询累计灌溉水量',
  start_irrigation: '开始灌溉',
  stop_irrigation: '停止灌溉',
  get_alarm_list: '查询告警列表',
  get_unprocessed_alarm_count: '查询未处理告警数',
  handle_alarm: '处理告警',
  get_monitor_points: '查询监测点列表',
  get_monitor_point_detail: '查询监测点详情',
  get_weather: '查询天气',
  predict_moisture: '土壤湿度预测',
  analyze_moisture_prediction: '分析湿度预测',
  get_learning_progress: '查询学习进度',
  get_learned_params: '查询学习参数',
  get_irrigation_strategy: '查询灌溉策略',
  set_crop_info: '设置作物信息',
  get_crop_stage_configs: '查询作物生育期配置',
  get_supported_crop_types: '查询作物类型',
  get_smart_irrigation_stats: '查询智能灌溉统计',
  search_knowledge_base: '知识库检索',
  rebuild_knowledge_index: '重建知识库索引',
};

export function toolLabel(name: string): string {
  if (TOOL_NAME_MAP[name]) return TOOL_NAME_MAP[name];
  if (name.startsWith('consult_') && name.endsWith('_expert')) {
    const expertId = name.slice('consult_'.length, -'_expert'.length);
    return `咨询${EXPERT_NAME_MAP[expertId] || expertId}`;
  }
  return name;
}

export const EXPERT_NAME_MAP: Record<string, string> = {
  device: '设备管理专家',
  irrigation: '灌溉管理专家',
  environment: '环境监测专家',
  smart_irrigation: '智能灌溉专家',
};
