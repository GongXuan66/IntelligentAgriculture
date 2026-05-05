from langchain_core.tools import tool
from app.services.http_client import java_client
import json


@tool(description="获取检测点灌溉记录列表。")
async def get_irrigation_logs(point_id: int = 1) -> str:
    """获取灌溉记录"""
    try:
        logs = await java_client.get_irrigation_logs(point_id=point_id)
        return json.dumps(logs, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 灌溉记录失败: {str(e)}"


@tool(description="获取检测点最近一次灌溉记录。")
async def get_latest_irrigation_log(point_id: int = 1) -> str:
    """获取最近灌溉记录"""
    try:
        log = await java_client.get_latest_irrigation_log(point_id=point_id)
        return json.dumps(log, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 最近灌溉记录失败: {str(e)}"


@tool(description="获取检测点累计灌溉水量。")
async def get_irrigation_total(point_id: int = 1) -> str:
    """获取总灌溉水量"""
    try:
        total = await java_client.get_irrigation_total(point_id=point_id)
        return json.dumps(total, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 总灌溉水量失败: {str(e)}"


@tool(description="开始灌溉，需传入point_id、duration、mode。")
async def start_irrigation(point_id: int, duration: int = 60, mode: int = 1) -> str:
    """开始灌溉"""
    try:
        payload = {"pointId": point_id, "duration": duration, "mode": mode}
        result = await java_client.start_irrigation(payload)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"开始灌溉失败: {str(e)}"


@tool(description="停止灌溉，需传入log_id。")
async def stop_irrigation(log_id: int) -> str:
    """停止灌溉"""
    try:
        result = await java_client.stop_irrigation(log_id)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"停止灌溉失败: {str(e)}"
