from typing import List, Dict, Any, Optional
from langchain_core.documents import Document
from app.rag.vector_store import VectorStoreManager
from app.rag.config import rag_settings


class RAGRetriever:
    """RAG 检索器"""

    def __init__(
        self,
        vector_store: Optional[VectorStoreManager] = None,
        top_k: Optional[int] = None,
        similarity_threshold: Optional[float] = None,
    ):
        self.vector_store = vector_store or VectorStoreManager()
        self.top_k = top_k or rag_settings.top_k
        self.similarity_threshold = similarity_threshold or rag_settings.similarity_threshold

    def search(
        self,
        query: str,
        top_k: Optional[int] = None,
        filter: Optional[Dict] = None,
    ) -> List[Dict[str, Any]]:
        """
        检索相关文档

        Args:
            query: 查询文本
            top_k: 返回 top-k 结果
            filter: 过滤条件

        Returns:
            检索结果列表
        """
        k = top_k or self.top_k

        results_with_score = self.vector_store.similarity_search_with_score(
            query, k=k, filter=filter
        )

        processed_results = []
        for doc, score in results_with_score:
            similarity = 1 - score

            if similarity < self.similarity_threshold:
                continue

            processed_results.append({
                "content": doc.page_content,
                "source": doc.metadata.get("source", "unknown"),
                "score": similarity,
                "metadata": doc.metadata,
            })

        return processed_results

    def search_with_context(
        self,
        query: str,
        top_k: Optional[int] = None,
    ) -> str:
        """
        检索并组装上下文

        Args:
            query: 查询文本
            top_k: 返回 top-k 结果

        Returns:
            组装后的上下文字符串
        """
        results = self.search(query, top_k=top_k)

        if not results:
            return ""

        context_parts = []
        for i, result in enumerate(results, 1):
            context_parts.append(
                f"[来源 {i}]: {result['source']}\n{result['content']}"
            )

        return "\n\n".join(context_parts)

    def get_sources(self, results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """提取来源信息"""
        sources = []
        for result in results:
            sources.append({
                "source": result.get("source", "unknown"),
                "score": result.get("score", 0),
            })
        return sources


rag_retriever = RAGRetriever()