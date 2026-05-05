from langchain_core.tools import tool
from app.services.http_client import java_client
import json


@tool(description="获取检测点列表，可按是否启用或农场筛选。")
async def get_monitor_points(active_only: bool = False, farm_id: int | None = None) -> str:
    """获取检测点列表"""
    try:
        points = await java_client.get_monitor_point_list(active_only=active_only, farm_id=farm_id)
        return json.dumps(points, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点列表失败: {str(e)}"


@tool(description="获取检测点详情。")
async def get_monitor_point_detail(point_id: int) -> str:
    """获取检测点详情"""
    try:
        point = await java_client.get_monitor_point_by_id(point_id)
        return json.dumps(point, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 详情失败: {str(e)}"
