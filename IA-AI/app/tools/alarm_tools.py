from langchain_core.tools import tool
from app.services.http_client import java_client
import json


@tool(description="获取报警列表，可按检测点或状态筛选。")
async def get_alarm_list(point_id: int | None = None, status: int | None = None) -> str:
    """获取报警列表"""
    try:
        alarms = await java_client.get_alarm_list(point_id=point_id, status=status)
        return json.dumps(alarms, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取报警列表失败: {str(e)}"


@tool(description="获取未处理报警数量，可按检测点筛选。")
async def get_unprocessed_alarm_count(point_id: int | None = None) -> str:
    """获取未处理报警数量"""
    try:
        count = await java_client.get_unprocessed_alarm_count(point_id=point_id)
        return json.dumps(count, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取未处理报警数量失败: {str(e)}"


@tool(description="处理报警记录，可选备注。")
async def handle_alarm(alarm_id: int, remark: str | None = None) -> str:
    """处理报警"""
    try:
        result = await java_client.handle_alarm(alarm_id, remark=remark)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"处理报警 {alarm_id} 失败: {str(e)}"
