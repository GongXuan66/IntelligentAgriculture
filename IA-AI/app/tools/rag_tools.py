from langchain_core.tools import tool
from app.rag.retriever import rag_retriever
from app.rag.pipeline import rag_pipeline


@tool(description="""
搜索知识库中的相关文档。

参数:
    query: 搜索关键词或问题描述
    top_k: 返回结果数量，默认5

返回:
    相关的文档片段列表，包含内容、来源和相似度分数
""")
def search_knowledge_base(query: str, top_k: int = 5) -> str:
    """
    搜索知识库

    Args:
        query: 搜索查询
        top_k: 返回数量

    Returns:
        格式化的检索结果
    """
    results = rag_retriever.search(query, top_k=top_k)

    if not results:
        return "未找到相关文档"

    output_parts = [f"找到 {len(results)} 条相关文档:\n"]
    for i, r in enumerate(results, 1):
        output_parts.append(
            f"\n--- 文档 {i} ---\n"
            f"来源: {r['source']}\n"
            f"相似度: {r['score']:.2%}\n"
            f"内容: {r['content'][:300]}..."
        )

    return "\n".join(output_parts)


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
        return f"索引重建成功！\n文档数: {result['indexed_documents']}\n文本块数: {result['indexed_chunks']}"
    else:
        return f"索引重建失败: {result.get('message', '未知错误')}"


__all__ = [
    "search_knowledge_base",
    "rebuild_knowledge_index",
]