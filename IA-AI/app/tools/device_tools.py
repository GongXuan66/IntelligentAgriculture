from langchain_core.tools import tool
from app.services.http_client import java_client
import json


@tool(description="获取系统中所有设备列表，包括设备的ID、名称、类型和当前状态。返回设备的基本信息。")
async def get_all_devices() -> str:
    """获取所有设备"""
    try:
        devices = await java_client.get_device_list()
        return json.dumps(devices, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取设备列表失败: {str(e)}"


@tool(description="""
根据检测点ID获取该检测点下的所有设备。
参数:
    point_id: 检测点ID (整数)
""")
async def get_devices_by_point_id(point_id: int) -> str:
    """获取指定检测点的设备"""
    try:
        devices = await java_client.get_device_list(point_id=point_id)
        return json.dumps(devices, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取检测点 {point_id} 的设备失败: {str(e)}"


@tool(description="""
根据设备编码获取设备的详细信息。
参数:
    device_code: 设备编码 (字符串)
""")
async def get_device_by_device_code(device_code: str) -> str:
    """获取设备详情（通过设备编码查状态）"""
    try:
        device = await java_client.get_device_status(device_code)
        return json.dumps(device, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取设备 {device_code} 详情失败: {str(e)}"


@tool(description="""
控制设备开关。

参数:
    device_code: 设备编码 (字符串)
    command: 命令，"on"开启设备，"off"关闭设备 (字符串，仅支持"on"或"off")
""")
async def control_device(device_code: str, command: str) -> str:
    """控制设备开关"""
    try:
        result = await java_client.control_device(device_code, command)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except ValueError as e:
        return f"参数错误: {str(e)}"
    except Exception as e:
        return f"控制设备 {device_code} 失败: {str(e)}"
