"""
RAG Query 侧优化：指代改写 + Multi-Query + 同义词扩展。

处理流程（每一步都有开关，失败时降级为原 query，绝不影响主流程）：
    1. 多轮指代改写：query 含"它/这个/那块地"等指代词且有对话历史时，
       用 LLM 把指代替换为具体实体，得到可独立检索的 query。
    2. Multi-Query：用 LLM 把 query 改写为多条不同表述，并行检索提升召回。
    3. 同义词扩展：纯规则生成农业领域同义变体（见 synonyms.py）。

成本说明：
- 指代改写仅在检测到指代词时调用 LLM；
- Multi-Query 每次检索固定一次 LLM 调用，可用 RAG_QUERY_REWRITE_MODEL
  配置便宜小模型（如 Qwen-Turbo）降低成本；
- 同义词扩展为本地规则，零成本。
"""
import logging
from typing import List, Optional, Sequence

from app.rag.config import rag_settings
from app.rag.synonyms import expand_with_synonyms

logger = logging.getLogger(__name__)

# 中文常见指代词（命中才触发指代改写，避免无谓的 LLM 调用）
COREF_MARKERS = ("它", "这个", "那个", "这块", "那块", "这棚", "那棚",
                 "该设备", "这台", "那台", "上述", "刚才说的")

_llm = None


def _get_llm():
    """Query 改写专用 LLM（懒加载单例，独立于主 Agent 避免循环依赖）"""
    global _llm
    if _llm is None:
        from langchain_openai import ChatOpenAI
        from app.config import settings
        _llm = ChatOpenAI(
            model=rag_settings.query_rewrite_model or settings.openai_model,
            api_key=settings.openai_api_key,
            base_url=settings.openai_api_url,
            temperature=0,
            streaming=False,
        )
    return _llm


async def resolve_coreference(
    query: str,
    history: Optional[Sequence[str]] = None,
) -> str:
    """
    多轮指代改写：把"它/这个设备/那块地"等指代替换为历史中的具体实体。

    Args:
        query: 用户当前问题
        history: 近期对话历史（"角色: 内容"格式的字符串列表，按时间正序）

    Returns:
        改写后的独立 query；无指代或无历史时原样返回
    """
    if not rag_settings.coref_enabled or not history:
        return query
    if not any(marker in query for marker in COREF_MARKERS):
        return query

    history_text = "\n".join(history[-6:])  # 只取最近几轮，控制 token
    prompt = f"""请根据对话历史，把用户最新问题中的指代词（如"它""这个""那块"）
替换为历史中提到的具体对象，输出一个可以独立理解的完整问题。
只输出改写后的问题本身，不要解释，不要加引号。如果问题中没有指代词，原样输出。

对话历史：
{history_text}

用户最新问题：{query}"""

    try:
        resp = await _get_llm().ainvoke(prompt)
        rewritten = resp.content.strip() if isinstance(resp.content, str) else query
        if rewritten and rewritten != query:
            logger.info(f"指代改写: '{query}' -> '{rewritten}'")
            return rewritten
    except Exception as e:
        logger.warning(f"指代改写失败，使用原 query: {e}")
    return query


async def generate_multi_queries(query: str, max_queries: int = 3) -> List[str]:
    """
    Multi-Query：把用户问题改写为多条不同表述的检索 query。

    Returns:
        query 列表，第一条恒为原 query
    """
    if not rag_settings.multi_query_enabled:
        return [query]

    prompt = f"""你是一个检索助手。请把下面的农业问题改写成 {max_queries - 1} 条
语义相同但表述不同的检索用问题（换用不同的关键词、换个问法），
用于在知识库中检索相关资料。每行输出一条，不要编号，不要解释。

原问题：{query}"""

    queries = [query]
    try:
        resp = await _get_llm().ainvoke(prompt)
        text = resp.content if isinstance(resp.content, str) else ""
        for line in text.strip().splitlines():
            line = line.strip().lstrip("0123456789.、- ").strip()
            if line and line != query and line not in queries:
                queries.append(line)
    except Exception as e:
        logger.warning(f"Multi-Query 改写失败，仅使用原 query: {e}")
    return queries


async def process_query(
    query: str,
    history: Optional[Sequence[str]] = None,
) -> List[str]:
    """
    Query 处理主入口：指代改写 -> Multi-Query -> 同义词扩展。

    Returns:
        检索 query 列表（第一条为处理后的主 query），
        数量不超过 rag_settings.max_queries
    """
    # 1. 指代改写
    resolved = await resolve_coreference(query, history)

    # 2. Multi-Query
    queries = await generate_multi_queries(resolved)

    # 3. 同义词扩展（对每条 query 生成变体）
    if rag_settings.synonym_enabled:
        expanded = list(queries)
        for q in queries:
            for variant in expand_with_synonyms(q):
                if variant not in expanded:
                    expanded.append(variant)
        queries = expanded

    return queries[: rag_settings.max_queries]
