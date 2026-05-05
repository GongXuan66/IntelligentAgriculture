from typing import List, Dict, Any, Optional
import logging
from app.rag.config import rag_settings

logger = logging.getLogger(__name__)


class Reranker:
    """结果重排序器（可选功能）"""

    def __init__(self, model_name: Optional[str] = None):
        self.model_name = model_name or rag_settings.rerank_model
        self.enabled = rag_settings.rerank_enabled and self.model_name is not None
        self._model = None

    def rerank(self, query: str, results: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """对检索结果重排序（目前是占位实现）"""
        if not self.enabled:
            return results
        # TODO: 实现实际的重排序逻辑
        return results


# 延迟初始化全局实例，避免导入时失败
_reranker: Optional[Reranker] = None


def get_reranker() -> Reranker:
    """获取全局 Reranker 实例（延迟初始化）"""
    global _reranker
    if _reranker is None:
        try:
            _reranker = Reranker()
            logger.info(f"Reranker 初始化成功, enabled={_reranker.enabled}")
        except Exception as e:
            logger.warning(f"Reranker 初始化失败: {e}，将禁用重排功能")
            _reranker = Reranker(model_name=None)
    return _reranker


# 向后兼容，提供全局实例访问
reranker = get_reranker()
