"""
真实 Rerank：本地 bge-reranker 精排（可离线运行）。

混合检索粗召回 top-N 后，用 CrossEncoder 对 (query, 文档) 对逐条打分精排。
模型默认 BAAI/bge-reranker-base（中文场景够用；多语言可换 bge-reranker-v2-m3）。

依赖说明：
    sentence-transformers 是可选依赖（uv sync --extra local-embed，间接依赖
    torch），仅在启用 rerank 时才需要；未安装或模型未下载时自动降级为跳过
    重排，不影响检索主流程。通过 RAG_RERANK_ENABLED=true / RAG_RERANK_MODEL=... 启用。
"""
from typing import List, Dict, Any, Optional
import logging
from app.rag.config import rag_settings

logger = logging.getLogger(__name__)


class Reranker:
    """bge-reranker 精排器（懒加载，缺依赖自动降级）"""

    def __init__(self, model_name: Optional[str] = None):
        self.model_name = model_name or rag_settings.rerank_model
        self.enabled = rag_settings.rerank_enabled and bool(self.model_name)
        self._model = None
        self._load_failed = False

    def _load_model(self):
        """懒加载 CrossEncoder（首次 rerank 时才加载，避免拖慢启动）"""
        if self._model is not None or self._load_failed:
            return self._model
        try:
            from sentence_transformers import CrossEncoder
            logger.info(f"加载 rerank 模型: {self.model_name}")
            self._model = CrossEncoder(self.model_name, max_length=512)
        except Exception as e:
            logger.warning(
                f"rerank 模型加载失败（{e}），本次运行禁用重排。"
                "需要 pip install sentence-transformers 并下载模型后启用"
            )
            self._load_failed = True
        return self._model

    def rerank(
        self,
        query: str,
        results: List[Dict[str, Any]],
        top_n: Optional[int] = None,
    ) -> List[Dict[str, Any]]:
        """
        对检索结果精排。

        Args:
            query: 用户原始问题（用主 query 而非改写变体）
            results: 粗召回结果（含 content 字段）
            top_n: 精排后返回条数，默认取配置 rerank_top_n

        Returns:
            按 rerank 分数降序的结果；未启用或降级时原样返回
        """
        if not self.enabled or not results:
            return results

        model = self._load_model()
        if model is None:
            return results

        try:
            pairs = [(query, r.get("content", "")) for r in results]
            scores = model.predict(pairs)
            for r, s in zip(results, scores):
                r["rerank_score"] = float(s)
            ranked = sorted(results, key=lambda x: x["rerank_score"], reverse=True)
            n = top_n or rag_settings.rerank_top_n
            return ranked[:n]
        except Exception as e:
            logger.warning(f"rerank 执行失败，返回粗排结果: {e}")
            return results


# 延迟初始化全局实例，避免导入时失败
_reranker: Optional[Reranker] = None


def get_reranker() -> Reranker:
    """获取全局 Reranker 实例（延迟初始化）"""
    global _reranker
    if _reranker is None:
        _reranker = Reranker()
        logger.info(f"Reranker 初始化, enabled={_reranker.enabled}")
    return _reranker


reranker = get_reranker()
