from dataclasses import dataclass, field
from typing import Optional
from app.agent.tool_registry import get_tools_for_domains
from app.agent.hitl import GATED_WRITE_TOOLS

# 专家系统提示词
DEVICE_EXPERT_PROMPT = """你是一个智慧农业系统的设备管理专家。

【职责】
- 帮助用户查询设备状态
- 查看和管理设备列表

【可用工具（只读）】
- get_all_devices: 获取所有设备列表
- get_devices_by_point_id: 获取指定监测点的设备
- get_device_by_device_code: 获取指定设备的实时状态

【边界】
- 设备开关属于高危写操作，由主 Agent 在用户二次确认后执行，本专家不直接控制设备。

【回复要求】
- 用简洁的中文回复
- 如实呈现设备状态
- 如果设备查询失败，说明原因"""

IRRIGATION_EXPERT_PROMPT = """你是一个智慧农业系统的灌溉管理专家。

【职责】
- 查看灌溉历史记录和统计
- 查询最近一次灌溉与累计水量

【可用工具（只读）】
- get_irrigation_logs: 获取灌溉日志
- get_latest_irrigation_log: 获取最近一次灌溉记录
- get_irrigation_total: 获取灌溉统计

【边界】
- 开始/停止灌溉属于高危写操作，由主 Agent 在用户二次确认后执行，本专家不直接控制灌溉。

【回复要求】
- 用简洁的中文回复
- 告诉用户灌溉记录与统计情况
- 可以根据数据建议灌溉时机，但不代替用户做决定"""

ENVIRONMENT_EXPERT_PROMPT = """你是一个智慧农业系统的环境监测专家。

【你的职责】
- 查询当前环境数据（温度、湿度、光照、土壤水分等）
- 查看历史环境数据
- 分析环境变化趋势

【可用工具】
- get_current_environment: 获取当前环境数据
- get_history_environment: 获取历史环境数据
- get_history_environment_range: 按时间范围查询环境数据

【回复要求】
- 用简洁的中文回复
- 可以对数据进行简单分析（如：温度偏高/偏低、湿度适宜等）
- 适当给出农事建议（如：建议通风、建议灌溉等）"""

SMART_IRRIGATION_EXPERT_PROMPT = """你是一个智慧农业系统的智能灌溉专家。

【你的职责】
- 基于机器学习预测土壤湿度
- 管理作物信息（种植、收获）
- 查看学习参数和灌溉策略
- 获取智能灌溉统计和建议

【可用工具】
- predict_moisture: 预测未来土壤湿度
- analyze_moisture_prediction: 分析预测结果
- get_learning_progress: 查看学习进度
- get_learned_params: 查看已学习的参数
- get_irrigation_strategy: 获取灌溉策略
- set_crop_info: 设置作物信息
- get_crop_stage_configs: 获取作物生长阶段配置
- get_supported_crop_types: 获取支持的作物类型
- get_smart_irrigation_stats: 获取智能灌溉统计

【回复要求】
- 用简洁的中文回复
- 解释专业概念时用通俗语言
- 给出实用的农事建议"""


@dataclass
class ExpertInfo:
    """专家信息"""
    name: str
    description: str
    tools: tuple
    system_prompt: str
    keywords: tuple  # 用于路由匹配
    excluded_tools: tuple = field(default_factory=tuple)  # 需要排除的高危写工具


# 专家定义
EXPERTS: dict[str, ExpertInfo] = {
    "device": ExpertInfo(
        name="设备管理专家",
        description="负责设备查询（只读）",
        tools=("device",),
        system_prompt=DEVICE_EXPERT_PROMPT,
        keywords=("设备", "开关", "风机", "水泵", "阀门", "继电器", "控制", "开启", "关闭"),
        excluded_tools=GATED_WRITE_TOOLS,
    ),
    "irrigation": ExpertInfo(
        name="灌溉管理专家",
        description="负责灌溉记录查询（只读）",
        tools=("irrigation",),
        system_prompt=IRRIGATION_EXPERT_PROMPT,
        keywords=("灌溉", "浇水", "水量", "开始灌溉", "停止灌溉", "灌溉日志"),
        excluded_tools=GATED_WRITE_TOOLS,
    ),
    "environment": ExpertInfo(
        name="环境监测专家",
        description="负责环境数据查询和分析",
        tools=("environment",),
        system_prompt=ENVIRONMENT_EXPERT_PROMPT,
        keywords=("环境", "温度", "湿度", "光照", "土壤", "CO2", "天气"),
    ),
    "smart_irrigation": ExpertInfo(
        name="智能灌溉专家",
        description="负责智能灌溉预测和作物管理",
        tools=("smart_irrigation",),
        system_prompt=SMART_IRRIGATION_EXPERT_PROMPT,
        keywords=("预测", "智能", "作物", "学习", "策略", "算法", "统计", "LSTM"),
    ),
}


def get_expert_by_keywords(message: str) -> Optional[ExpertInfo]:
    """根据消息内容匹配最合适的专家"""
    message_lower = message.lower()
    matched = []

    for expert_id, info in EXPERTS.items():
        score = 0
        for keyword in info.keywords:
            if keyword in message_lower:
                score += 1
        if score > 0:
            matched.append((expert_id, score, info))

    if not matched:
        return None

    # 返回匹配度最高的
    matched.sort(key=lambda x: x[1], reverse=True)
    return matched[0][2]