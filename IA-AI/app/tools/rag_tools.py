import logging
import os
from typing import Any, Dict, List, Optional

from langchain_core.runnables import RunnableConfig
from langchain_core.tools import tool

from app.rag.config import rag_settings
from app.rag.hybrid import hybrid_retriever
from app.rag.pipeline import rag_pipeline
from app.rag.query_processor import process_query
from app.rag.retriever import rag_retriever

logger = logging.getLogger(__name__)

# 空检索固定兜底文案：主 Agent 提示词以此文案约束"不得编造"，
# 修改此处必须同步修改 assistant.py 的 MAIN_AGENT_PROMPT。
EMPTY_RESULT_MESSAGE = "知识库中未查询到相关内容"


async def _load_history(config: Optional[RunnableConfig]) -> List[str]:
    """从 checkpointer 读取当前会话近期历史（供多轮指代改写使用）。

    任何异常都降级为空历史，不影响检索主流程。
    """
    thread_id = None
    if config:
        thread_id = (config.get("configurable") or {}).get("thread_id")
    if not thread_id:
        return []

    try:
        from app.agent.assistant import get_checkpointer  # 延迟导入避免循环依赖
        checkpointer = get_checkpointer()
        if not checkpointer:
            return []
        state = await checkpointer.aget({"configurable": {"thread_id": thread_id}})
        messages = (state or {}).get("channel_values", {}).get("messages", [])
    except Exception as e:
        logger.debug(f"读取会话历史失败，跳过指代改写: {e}")
        return []

    history = []
    for msg in messages[-6:]:
        role = "用户" if getattr(msg, "type", "") == "human" else "助手"
        content = msg.content if isinstance(msg.content, str) else ""
        # 过长的工具中间结果不纳入，控制 token
        if content and len(content) < 500:
            history.append(f"{role}: {content}")
    return history


def _format_source_path(result: Dict[str, Any]) -> str:
    """由代码拼接确定性来源：文档名 > 标题层级（不允许模型生成来源）"""
    source = result.get("source", "unknown")
    doc_name = os.path.basename(str(source))
    meta = result.get("metadata") or {}
    headers = [meta[f"h{i}"].strip() for i in range(1, 5) if meta.get(f"h{i}")]
    if headers:
        return f"{doc_name} > {' > '.join(headers)}"
    return doc_name


def _format_results(results: List[Dict[str, Any]]) -> str:
    """确定性结果组装：来源标注、分数、完整内容均由代码拼接"""
    parts = [f"在知识库中检索到 {len(results)} 条相关内容：\n"]
    for i, r in enumerate(results, 1):
        score = r.get("score")
        score_text = f"{score:.2f}" if isinstance(score, (int, float)) else "关键词命中"
        parts.append(
            f"【来源 {i}】{_format_source_path(r)}\n"
            f"相关度: {score_text}\n"
            f"{r['content']}\n"
        )
    return "\n".join(parts)


@tool(description="""
搜索知识库中的相关文档（农业知识、设备操作、故障排查、灌溉指南等）。

参数:
    query: 搜索关键词或问题描述
    top_k: 返回结果数量，默认5

返回:
    相关的文档片段列表，包含确定性来源标注（文档名与章节）、相关度和内容；
    若无结果则返回固定提示"知识库中未查询到相关内容"
""")
async def search_knowledge_base(
    query: str,
    top_k: int = 5,
    config: RunnableConfig = None,
) -> str:
    """
    搜索知识库（Query 改写 + 混合检索 + 同源分块补全）

    处理链：多轮指代改写（有历史且含指代词时）-> Multi-Query 改写
    -> 农业同义词扩展 -> BM25 + 向量混合检索（RRF 融合）
    -> 相邻分块回填 -> 确定性来源标注。
    """
    history = await _load_history(config)
    queries = await process_query(query, history)

    if rag_settings.hybrid_enabled:
        results = hybrid_retriever.search(queries, top_k=top_k)
    else:
        # 单路向量检索（降级路径）：只用处理后的主 query
        results = rag_retriever.search(queries[0], top_k=top_k)

    if not results:
        return EMPTY_RESULT_MESSAGE

    # 同源分块补全：回填同文档前后相邻块，避免答案被 chunk 边界截断
    if rag_settings.neighbor_expand:
        results = rag_retriever.expand_with_neighbors(
            results, window=rag_settings.neighbor_window
        )

    return _format_results(results)


@tool(description="""
重建知识库索引。

参数:
    directory: 文档目录路径，默认使用配置中的文档目录

返回:
    索引重建结果统计
""")
def rebuild_knowledge_index(directory: str = "") -> str:
    """
    重建知识库索引

    Args:
        directory: 文档目录路径

    Returns:
        索引结果
    """
    result = rag_pipeline.rebuild_index(directory or None)

    if result["status"] == "success":
        # 向量索引重建后同步刷新 BM25 语料，保持两路检索同源
        try:
            hybrid_retriever.refresh()
        except Exception as e:
            logger.warning(f"BM25 语料刷新失败（不影响向量检索）: {e}")
        return f"索引重建成功！\n文档数: {result['indexed_documents']}\n文本块数: {result['indexed_chunks']}"
    else:
        return f"索引重建失败: {result.get('message', '未知错误')}"


__all__ = [
    "search_knowledge_base",
    "rebuild_knowledge_index",
]
