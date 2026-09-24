"""
混合检索：BM25（关键词召回）+ Chroma 向量（语义召回），RRF 倒数排名融合。

解决中文短 query（如"风扇不转怎么办"）纯向量检索容易漏掉关键词匹配的问题。
BM25 语料直接取向量库中已入库的分块（与向量索引同源，重建索引后调用
refresh() 刷新即可），分词用 jieba。

RRF 融合公式：score(d) = Σ 1 / (rrf_k + rank + 1)，
对每条 query 的两路结果分别计算后累加，多 query 天然支持。
"""
import logging
from typing import Any, Dict, List, Optional

import jieba
from rank_bm25 import BM25Okapi

from app.rag.config import rag_settings
from app.rag.retriever import RAGRetriever
from app.rag.vector_store import VectorStoreManager

logger = logging.getLogger(__name__)

jieba.setLogLevel(logging.WARNING)


class HybridRetriever:
    """BM25 + 向量混合检索器（RRF 融合）"""

    def __init__(
        self,
        vector_store: Optional[VectorStoreManager] = None,
        retriever: Optional[RAGRetriever] = None,
    ):
        self.vector_store = vector_store or VectorStoreManager()
        self.retriever = retriever or RAGRetriever(vector_store=self.vector_store)
        self._corpus: List[Dict[str, Any]] = []
        self._bm25: Optional[BM25Okapi] = None

    # ------------------------------------------------------------------
    # BM25 语料（与向量库同源）
    # ------------------------------------------------------------------

    @staticmethod
    def _tokenize(text: str) -> List[str]:
        return [w for w in jieba.cut(text) if w.strip()]

    def refresh(self):
        """从向量库全量取回分块，重建 BM25 索引（索引重建后需调用）"""
        try:
            got = self.vector_store.vectorstore.get(include=["documents", "metadatas"])
        except Exception as e:
            logger.error(f"BM25 语料加载失败: {e}")
            self._corpus, self._bm25 = [], None
            return

        self._corpus = [
            {
                "content": content,
                "source": (meta or {}).get("source", "unknown"),
                "metadata": meta or {},
            }
            for content, meta in zip(got.get("documents", []), got.get("metadatas", []))
            if content
        ]
        tokenized = [self._tokenize(d["content"]) for d in self._corpus]
        self._bm25 = BM25Okapi(tokenized) if tokenized else None
        logger.info(f"BM25 索引已刷新，语料 {len(self._corpus)} 块")

    def _ensure_bm25(self) -> Optional[BM25Okapi]:
        if self._bm25 is None:
            self.refresh()
        return self._bm25

    def _bm25_search(self, query: str, k: int) -> List[Dict[str, Any]]:
        """BM25 关键词检索，返回带 bm25_rank 的候选"""
        bm25 = self._ensure_bm25()
        if bm25 is None or not self._corpus:
            return []

        scores = bm25.get_scores(self._tokenize(query))
        top_indices = sorted(
            range(len(scores)), key=lambda i: scores[i], reverse=True
        )[:k]

        candidates = []
        for rank, i in enumerate(top_indices):
            if scores[i] <= 0:
                continue
            item = dict(self._corpus[i])
            item["bm25_rank"] = rank
            candidates.append(item)
        return candidates

    # ------------------------------------------------------------------
    # RRF 融合
    # ------------------------------------------------------------------

    @staticmethod
    def _dedupe_key(item: Dict[str, Any]) -> str:
        meta = item.get("metadata") or {}
        src = item.get("source", "unknown")
        idx = meta.get("chunk_index")
        if isinstance(idx, int):
            return f"{src}#{idx}"
        return f"{src}#{hash(item.get('content', '')[:200])}"

    def search(
        self,
        queries: List[str],
        top_k: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        """
        混合检索主入口。

        Args:
            queries: 检索 query 列表（原 query + 改写/扩展变体）
            top_k: 最终返回条数

        Returns:
            按 RRF 分数降序的结果列表，字段与 RAGRetriever.search 一致，
            额外带 rrf_score / vector_score / bm25_rank 供观测
        """
        k = top_k or rag_settings.top_k
        candidate_k = rag_settings.candidate_k
        rrf_k = rag_settings.rrf_k

        # rrf 累加表：key -> {entry, rrf}
        fused: Dict[str, Dict[str, Any]] = {}

        def add_candidates(items: List[Dict[str, Any]], rank_key: str):
            for item in items:
                key = self._dedupe_key(item)
                rank = item.get(rank_key)
                if rank is None:
                    continue
                entry = fused.setdefault(key, {"entry": item, "rrf": 0.0})
                entry["rrf"] += 1.0 / (rrf_k + rank + 1)
                # 保留更完整的条目信息（向量路带 similarity）
                if rank_key == "vector_rank":
                    entry["entry"] = item

        for query in queries:
            # 向量路（宽松阈值粗召回）
            vector_hits = self.retriever.search(
                query,
                top_k=candidate_k,
                threshold=rag_settings.hybrid_vector_threshold,
            )
            for rank, hit in enumerate(vector_hits):
                hit["vector_rank"] = rank
            add_candidates(vector_hits, "vector_rank")

            # BM25 路
            bm25_hits = self._bm25_search(query, candidate_k)
            add_candidates(bm25_hits, "bm25_rank")

        if not fused:
            return []

        ordered = sorted(fused.values(), key=lambda x: x["rrf"], reverse=True)

        # 可选精排：粗召回 candidate_k 条，用主 query 做 CrossEncoder 精排
        if rag_settings.rerank_enabled and ordered:
            from app.rag.model.reranker import get_reranker
            candidates = [item["entry"] for item in ordered[: rag_settings.candidate_k]]
            return get_reranker().rerank(queries[0], candidates)

        results = []
        for item in ordered[:k]:
            entry = item["entry"]
            results.append({
                "content": entry.get("content", ""),
                "source": entry.get("source", "unknown"),
                # 向量相似度（纯 BM25 命中的条目可能为 None）
                "score": entry.get("score"),
                "rrf_score": round(item["rrf"], 6),
                "metadata": entry.get("metadata") or {},
            })
        return results


# 全局单例（BM25 语料懒加载）
hybrid_retriever = HybridRetriever()
