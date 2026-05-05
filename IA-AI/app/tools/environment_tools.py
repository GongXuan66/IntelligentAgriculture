from langchain_core.tools import tool
from app.services.http_client import java_client
import json


@tool(description="获取当前检测点的环境数据，返回温度、湿度、光照、土壤湿度等实时信息。")
async def get_current_environment(point_id: int = 1) -> str:
    """获取当前环境数据"""
    try:
        data = await java_client.get_current_environment(point_id=point_id)
        return json.dumps(data, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 当前环境数据失败: {str(e)}"


@tool(description="获取检测点的历史环境数据，支持limit参数控制返回条数。")
async def get_history_environment(point_id: int = 1, limit: int = 100) -> str:
    """获取历史环境数据"""
    try:
        data = await java_client.get_history_environment(point_id=point_id, limit=limit)
        return json.dumps(data, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 历史环境数据失败: {str(e)}"


@tool(description="按时间范围查询检测点历史环境数据，时间格式: yyyy-MM-dd HH:mm:ss。")
async def get_history_environment_range(
    point_id: int,
    start_time: str,
    end_time: str,
) -> str:
    """按时间范围查询历史环境数据"""
    try:
        data = await java_client.get_history_environment_range(
            point_id=point_id,
            start_time=start_time,
            end_time=end_time,
        )
        return json.dumps(data, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 时间范围历史环境数据失败: {str(e)}"
