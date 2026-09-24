"""
输出侧护轨：工具执行结果校验 + 失败自动重试。

- is_error_result: 识别工具返回文本中的失败特征
- wrap_tool_with_retry: 把只读工具包装为"失败自动重试"版本，
  异常或命中失败特征时按策略重试，重试耗尽后返回结构化失败信息
  （模型可据此如实告知用户，而不是拿到一段异常栈）。

注意：只包装只读查询工具；高危写工具走 hitl 人工确认，不在此包装。
"""
import asyncio
import logging
from typing import Any

from langchain_core.tools import BaseTool, StructuredTool

logger = logging.getLogger(__name__)

# 工具返回文本中的失败特征（命中视为执行失败，可触发重试）
ERROR_MARKERS = (
    "请求失败",
    "调用失败",
    "接口异常",
    "连接超时",
    "连接失败",
    "处理请求时出错",
    "connection refused",
    "connection timeout",
    "read timeout",
    "502 bad gateway",
    "503 service unavailable",
)

# 重试之间的退避间隔（秒）
RETRY_BACKOFF_SECONDS = 0.5


def is_error_result(result: Any) -> bool:
    """判断工具返回结果是否为失败"""
    if not isinstance(result, str):
        return False
    lowered = result.lower()
    return any(marker.lower() in lowered for marker in ERROR_MARKERS)


def wrap_tool_with_retry(tool: BaseTool, max_retries: int = 1) -> BaseTool:
    """
    把工具包装为失败自动重试版本（保持名称、描述、参数 schema 不变）。

    Args:
        tool: 原始工具（只读工具）
        max_retries: 最大重试次数（不含首次执行）

    Returns:
        包装后的 StructuredTool
    """
    original = tool

    async def _run_with_retry(**kwargs) -> str:
        last_error: Any = None
        for attempt in range(max_retries + 1):
            try:
                result = await original.ainvoke(kwargs)
                if is_error_result(result) and attempt < max_retries:
                    logger.warning(
                        f"工具 {original.name} 返回失败特征，"
                        f"第 {attempt + 1} 次重试: {str(result)[:100]}"
                    )
                    await asyncio.sleep(RETRY_BACKOFF_SECONDS)
                    continue
                return result
            except Exception as e:  # noqa: BLE001 - 统一转换为结构化失败文本
                last_error = e
                logger.warning(
                    f"工具 {original.name} 异常，"
                    f"第 {attempt + 1} 次重试: {e}"
                )
                if attempt < max_retries:
                    await asyncio.sleep(RETRY_BACKOFF_SECONDS)
        return (
            f"工具 {original.name} 调用失败（已自动重试 {max_retries} 次）："
            f"{last_error}。请如实告知用户当前查询暂时不可用，建议稍后重试。"
        )

    return StructuredTool(
        name=original.name,
        description=original.description or "",
        args_schema=original.args_schema,
        coroutine=_run_with_retry,
    )
