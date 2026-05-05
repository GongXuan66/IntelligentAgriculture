from dataclasses import dataclass
from typing import Iterable

from app.tools.device_tools import (
    get_all_devices,
    get_devices_by_point_id,
    get_device_by_device_code,
    control_device,
)
from app.tools.environment_tools import (
    get_current_environment,
    get_history_environment,
    get_history_environment_range,
)
from app.tools.irrigation_tools import (
    get_irrigation_logs,
    get_latest_irrigation_log,
    get_irrigation_total,
    start_irrigation,
    stop_irrigation,
)
from app.tools.alarm_tools import (
    get_alarm_list,
    get_unprocessed_alarm_count,
    handle_alarm,
)
from app.tools.monitor_tools import (
    get_monitor_points,
    get_monitor_point_detail,
)
from app.tools.weather_tool import get_weather
from app.tools.smart_irrigation_tools import (
    predict_moisture,
    analyze_moisture_prediction,
    get_learning_progress,
    get_learned_params,
    get_irrigation_strategy,
    set_crop_info,
    get_crop_stage_configs,
    get_supported_crop_types,
    get_smart_irrigation_stats,
)
from app.tools.rag_tools import search_knowledge_base, rebuild_knowledge_index


@dataclass(frozen=True)
class ToolGroup:
    name: str
    tools: tuple


TOOL_GROUPS: dict[str, ToolGroup] = {
    # 设备管理
    "device": ToolGroup(
        name="device",
        tools=(
            get_all_devices,
            get_devices_by_point_id,
            get_device_by_device_code,
            control_device,
        ),
    ),
    # 环境监测
    "environment": ToolGroup(
        name="environment",
        tools=(
            get_current_environment,
            get_history_environment,
            get_history_environment_range,
        ),
    ),
    # 灌溉控制
    "irrigation": ToolGroup(
        name="irrigation",
        tools=(
            get_irrigation_logs,
            get_latest_irrigation_log,
            get_irrigation_total,
            start_irrigation,
            stop_irrigation,
        ),
    ),
    # 报警管理
    "alarm": ToolGroup(
        name="alarm",
        tools=(
            get_alarm_list,
            get_unprocessed_alarm_count,
            handle_alarm,
        ),
    ),
    # 监控点管理
    "monitor": ToolGroup(
        name="monitor",
        tools=(
            get_monitor_points,
            get_monitor_point_detail,
        ),
    ),
    # 天气查询
    "weather": ToolGroup(
        name="weather",
        tools=(get_weather,),
    ),
    # 智能灌溉
    "smart_irrigation": ToolGroup(
        name="smart_irrigation",
        tools=(
            predict_moisture,
            analyze_moisture_prediction,
            get_learning_progress,
            get_learned_params,
            get_irrigation_strategy,
            set_crop_info,
            get_crop_stage_configs,
            get_supported_crop_types,
            get_smart_irrigation_stats,
        ),
    ),
    # RAG 知识库
    "rag": ToolGroup(
        name="rag",
        tools=(
            search_knowledge_base,
            rebuild_knowledge_index,
        ),
    ),
    # 农场管理（暂不暴露给Agent，避免操作风险）
    # "farm": ToolGroup(...),
}


def get_tools_for_domains(domains: Iterable[str]) -> list:
    """根据域获取对应的工具列表"""
    tools: list = []
    for domain in domains:
        group = TOOL_GROUPS.get(domain)
        if group:
            tools.extend(group.tools)
    return tools


def get_all_tools() -> list:
    """获取所有可用工具"""
    all_tools = []
    for group in TOOL_GROUPS.values():
        all_tools.extend(group.tools)
    return all_tools