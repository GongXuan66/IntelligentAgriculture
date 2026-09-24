"""高危写操作的人在环路（Human-in-the-loop）包装。

每个 gated 工具在真正调用后端前，先通过 LangGraph 的 interrupt() 暂停
执行并向前端抛出 approval_request；用户通过 /api/chat/resume 传入
{"approved": true/false} 后执行流才会恢复：

- approved=true  -> 调用原始写工具，返回真实执行结果
- approved=false -> 不执行任何写操作，返回"用户已拒绝"提示给模型

注意：interrupt 恢复时整个工具函数会被重新执行，interrupt() 的返回值
变为 resume 载荷，因此原始工具只在批准分支执行一次，不会重复调用。
"""
from langchain_core.tools import tool
from langgraph.types import interrupt

from app.tools.device_tools import control_device as _control_device
from app.tools.irrigation_tools import (
    start_irrigation as _start_irrigation,
    stop_irrigation as _stop_irrigation,
)
from app.tools.alarm_tools import handle_alarm as _handle_alarm


# 需要人工确认的写工具集合（SSE 层与专家装配共用）
GATED_WRITE_TOOLS: tuple[str, ...] = (
    "control_device",
    "start_irrigation",
    "stop_irrigation",
    "handle_alarm",
)

# 专家（只读子 Agent）需要排除的写工具
EXPERT_EXCLUDED_TOOLS: tuple[str, ...] = GATED_WRITE_TOOLS


def _request_approval(tool_name: str, args: dict, summary: str) -> dict:
    """发起中断，等待人工审批，返回 resume 载荷 {"approved": bool}。"""
    payload = {
        "type": "approval_request",
        "tool": tool_name,
        "args": args,
        "summary": summary,
    }
    decision = interrupt(payload)
    if isinstance(decision, dict):
        return decision
    return {"approved": bool(decision)}


@tool(
    "control_device",
    description="""
控制设备开关（高危操作，执行前必须等待用户在界面上确认）。

参数:
    device_code: 设备编码 (字符串)
    command: 命令，"on"开启设备，"off"关闭设备 (字符串，仅支持"on"或"off")
""",
)
async def control_device(device_code: str, command: str) -> str:
    """控制设备开关（人工确认）"""
    args = {"device_code": device_code, "command": command}
    summary = f"对设备 {device_code} 执行 {'开启' if str(command).lower() == 'on' else '关闭'} 操作"
    decision = _request_approval("control_device", args, summary)
    if not decision.get("approved"):
        return f"用户已拒绝执行：{summary}，设备状态未改变。"
    return await _control_device.ainvoke(args)


@tool(
    "start_irrigation",
    description="""
开始灌溉（高危操作，执行前必须等待用户在界面上确认）。

参数:
    point_id: 监测点ID (整数)
    duration: 灌溉时长，单位秒，默认60 (整数)
    mode: 灌溉模式，默认1 (整数)
""",
)
async def start_irrigation(point_id: int, duration: int = 60, mode: int = 1) -> str:
    """开始灌溉（人工确认）"""
    args = {"point_id": point_id, "duration": duration, "mode": mode}
    summary = f"在监测点 {point_id} 开始灌溉，时长 {duration} 秒，模式 {mode}"
    decision = _request_approval("start_irrigation", args, summary)
    if not decision.get("approved"):
        return f"用户已拒绝执行：{summary}，灌溉未启动。"
    return await _start_irrigation.ainvoke(args)


@tool(
    "stop_irrigation",
    description="""
停止灌溉（高危操作，执行前必须等待用户在界面上确认）。

参数:
    log_id: 进行中的灌溉记录ID (整数)
""",
)
async def stop_irrigation(log_id: int) -> str:
    """停止灌溉（人工确认）"""
    args = {"log_id": log_id}
    summary = f"停止灌溉记录 {log_id}"
    decision = _request_approval("stop_irrigation", args, summary)
    if not decision.get("approved"):
        return f"用户已拒绝执行：{summary}，灌溉继续进行。"
    return await _stop_irrigation.ainvoke(args)


@tool(
    "handle_alarm",
    description="""
处理（确认）报警记录（高危操作，执行前必须等待用户在界面上确认），可选备注。

参数:
    alarm_id: 报警记录ID (整数)
    remark: 处理备注 (字符串，可选)
""",
)
async def handle_alarm(alarm_id: int, remark: str | None = None) -> str:
    """处理报警（人工确认）"""
    args = {"alarm_id": alarm_id, "remark": remark}
    summary = f"将报警 {alarm_id} 标记为已处理" + (f"，备注：{remark}" if remark else "")
    decision = _request_approval("handle_alarm", args, summary)
    if not decision.get("approved"):
        return f"用户已拒绝执行：{summary}，报警保持未处理状态。"
    return await _handle_alarm.ainvoke(args)
