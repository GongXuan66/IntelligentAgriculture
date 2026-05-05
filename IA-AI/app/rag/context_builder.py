from typing import List, Dict, Any, Optional
from app.rag.retriever import rag_retriever
from app.rag.config import rag_settings


class ContextBuilder:
    """上下文构建器"""

    def __init__(self):
        self.retriever = rag_retriever

    def build(
        self,
        query: str,
        include_sources: bool = True,
        max_context_length: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        构建检索上下文

        Args:
            query: 用户查询
            include_sources: 是否包含来源信息
            max_context_length: 最大上下文长度（字符数）

        Returns:
            包含 context、sources、results 的字典
        """
        results = self.retriever.search(query)
        context = self._assemble_context(results, max_context_length)

        response = {
            "context": context,
            "results": results,
        }

        if include_sources:
            response["sources"] = self.retriever.get_sources(results)

        return response

    def _assemble_context(
        self,
        results: List[Dict[str, Any]],
        max_length: Optional[int] = None,
    ) -> str:
        """组装上下文字符串"""
        if not results:
            return ""

        context_parts = []
        total_length = 0
        max_len = max_length or 2000

        for i, result in enumerate(results, 1):
            part = f"【文档 {i}】({result['source']})\n{result['content']}"

            if max_len and total_length + len(part) > max_len:
                break

            context_parts.append(part)
            total_length += len(part)

        if not context_parts:
            return ""

        header = "以下是检索到的相关文档信息：\n\n"
        return header + "\n\n".join(context_parts)

    def format_for_llm(
        self,
        query: str,
        system_prompt: Optional[str] = None,
    ) -> str:
        """
        格式化给 LLM 的上下文

        Args:
            query: 用户查询
            system_prompt: 系统提示词

        Returns:
            格式化后的完整上下文
        """
        context_data = self.build(query)

        default_system = """你是一个智慧农业系统的专业助手。当用户询问操作指南、故障排查、功能说明等问题时，请根据提供的文档知识进行回答。如果文档中没有相关信息，请如实告知用户。"""

        system = system_prompt or default_system

        prompt_parts = [
            f"{system}\n",
            f"\n用户问题: {query}\n",
            f"\n{context_data['context']}\n",
            "\n请根据以上文档知识回答用户问题。如果信息不足，请说明情况。",
        ]

        return "".join(prompt_parts)


context_builder = ContextBuilder()