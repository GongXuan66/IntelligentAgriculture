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
        threshold: Optional[float] = None,
    ) -> List[Dict[str, Any]]:
        """
        检索相关文档

        Args:
            query: 查询文本
            top_k: 返回 top-k 结果
            filter: 过滤条件
            threshold: 覆盖默认相似度阈值（混合检索粗召回时传入更宽松值）

        Returns:
            检索结果列表
        """
        k = top_k or self.top_k
        limit = self.similarity_threshold if threshold is None else threshold

        results_with_score = self.vector_store.similarity_search_with_score(
            query, k=k, filter=filter
        )

        processed_results = []
        for doc, score in results_with_score:
            # collection 使用余弦距离（hnsw:space=cosine），
            # Chroma 返回的 score 是余弦距离，余弦相似度 = 1 - 距离，取值 [-1, 1]
            similarity = 1 - score

            if similarity < limit:
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

    # ------------------------------------------------------------------
    # 同源分块补全（small-to-big 简化版）
    # ------------------------------------------------------------------

    def _fetch_chunks_by_index(self, source: str, indices: List[int]) -> Dict[int, str]:
        """按 (source, chunk_index) 从向量库取回相邻分块，{chunk_index: content}"""
        indices = [i for i in indices if isinstance(i, int) and i >= 0]
        if not indices:
            return {}
        try:
            got = self.vector_store.vectorstore.get(
                where={
                    "$and": [
                        {"source": {"$eq": source}},
                        {"chunk_index": {"$in": indices}},
                    ]
                },
                include=["documents", "metadatas"],
            )
        except Exception:
            # 老索引没有 chunk_index 元数据时静默降级，不做补全
            return {}

        out: Dict[int, str] = {}
        for content, meta in zip(got.get("documents", []), got.get("metadatas", [])):
            idx = (meta or {}).get("chunk_index")
            if isinstance(idx, int):
                out[idx] = content
        return out

    def expand_with_neighbors(
        self,
        results: List[Dict[str, Any]],
        window: int = 1,
    ) -> List[Dict[str, Any]]:
        """
        同源分块补全：命中分块的前后各 window 个同文档相邻块回填合并，
        避免答案被 chunk 边界截断。

        合并后的结果保留原命中分数，metadata 标记 expanded=True。
        老索引缺少 chunk_index 元数据时自动降级为原样返回。
        """
        if not results or window <= 0:
            return results

        expanded_results = []
        for r in results:
            meta = r.get("metadata") or {}
            src = r.get("source")
            idx = meta.get("chunk_index")
            if not src or not isinstance(idx, int):
                expanded_results.append(r)
                continue

            want = list(range(idx - window, idx + window + 1))
            neighbors = self._fetch_chunks_by_index(src, want)
            if idx not in neighbors:
                # 索引中没有相邻块信息（老索引），原样返回
                expanded_results.append(r)
                continue

            merged_content = "".join(
                neighbors[i] for i in sorted(neighbors.keys())
            )
            merged = dict(r)
            merged["content"] = merged_content
            merged_meta = dict(meta)
            merged_meta["expanded"] = True
            merged_meta["expanded_from"] = sorted(neighbors.keys())
            merged["metadata"] = merged_meta
            expanded_results.append(merged)

        return expanded_results


rag_retriever = RAGRetriever()