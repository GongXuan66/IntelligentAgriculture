from dataclasses import dataclass
from typing import Optional
from app.agent.tool_registry import get_tools_for_domains

# 专家系统提示词
DEVICE_EXPERT_PROMPT = """你是一个智慧农业系统的设备管理专家。

【你的职责】
- 帮助用户查询设备状态
- 控制设备开关（如水泵、风机、阀门等）
- 查看和管理设备列表

【可用工具】
- get_all_devices: 获取所有设备列表
- get_devices_by_point_id: 获取指定检测点的设备
- get_device_by_device_code: 获取指定设备的实时状态
- control_device: 控制设备开关（需要设备编码和命令：on/off）

【回复要求】
- 用简洁的中文回复
- 告诉用户操作结果
- 如果设备无法操作，说明原因"""

IRRIGATION_EXPERT_PROMPT = """你是一个智慧农业系统的灌溉管理专家。

【你的职责】
- 手动控制灌溉开始和停止
- 查看灌溉历史记录和统计
- 管理自动灌溉计划

【可用工具】
- get_irrigation_logs: 获取灌溉日志
- get_latest_irrigation_log: 获取最近一次灌溉记录
- get_irrigation_total: 获取灌溉统计
- start_irrigation: 开始灌溉
- stop_irrigation: 停止灌溉
- get_auto_irrigation_plan: 获取自动灌溉计划
- start_auto_irrigation: 启动自动灌溉

【回复要求】
- 用简洁的中文回复
- 告诉用户灌溉状态和操作结果
- 可以根据环境数据建议灌溉时机"""

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


# 专家定义
EXPERTS: dict[str, ExpertInfo] = {
    "device": ExpertInfo(
        name="设备管理专家",
        description="负责设备查询和控制",
        tools=("device",),
        system_prompt=DEVICE_EXPERT_PROMPT,
        keywords=("设备", "开关", "风机", "水泵", "阀门", "继电器", "控制", "开启", "关闭")
    ),
    "irrigation": ExpertInfo(
        name="灌溉管理专家",
        description="负责灌溉控制和日志查看",
        tools=("irrigation",),
        system_prompt=IRRIGATION_EXPERT_PROMPT,
        keywords=("灌溉", "浇水", "水量", "开始灌溉", "停止灌溉", "灌溉日志")
    ),
    "environment": ExpertInfo(
        name="环境监测专家",
        description="负责环境数据查询和分析",
        tools=("environment",),
        system_prompt=ENVIRONMENT_EXPERT_PROMPT,
        keywords=("环境", "温度", "湿度", "光照", "土壤", "CO2", "天气")
    ),
    "smart_irrigation": ExpertInfo(
        name="智能灌溉专家",
        description="负责智能灌溉预测和作物管理",
        tools=("smart_irrigation",),
        system_prompt=SMART_IRRIGATION_EXPERT_PROMPT,
        keywords=("预测", "智能", "作物", "学习", "策略", "算法", "统计", "LSTM")
    ),
}


def get_expert_tools() -> list:
    """获取所有Expert作为Tool（供主Agent使用）"""
    from langchain_core.tools import tool

    tools = []

    for expert_id, info in EXPERTS.items():
        @tool(description=f"{info.description}。当你需要{expert_id}相关帮助时调用此工具。")
        async def call_expert(query: str, expert: str = expert_id) -> str:
            """调用专家Agent处理请求"""
            # 这里会被动态替换为实际的Expert Agent调用
            return f"[Expert: {expert}] 处理中: {query}"

        tools.append(call_expert)

    return tools


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