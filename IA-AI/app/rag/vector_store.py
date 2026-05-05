from typing import List, Optional, Dict, Any
import logging
from pathlib import Path
from langchain_chroma import Chroma
from langchain_core.documents import Document
from app.rag.config import rag_settings
from app.rag.model.embeddings import ModelScopeEmbeddings
from app.config import settings

logger = logging.getLogger(__name__)


class VectorStoreManager:
    """向量存储管理器"""

    def __init__(
        self,
        collection_name: str = "default",
        persist_directory: Optional[str] = None,
    ):
        self.collection_name = collection_name
        self.persist_directory = persist_directory or rag_settings.persist_dir

        Path(self.persist_directory).mkdir(parents=True, exist_ok=True)

        self._embeddings = None
        self._vectorstore: Optional[Chroma] = None

    @property
    def embeddings(self):
        """延迟初始化 embeddings"""
        if self._embeddings is None:
            self._embeddings = self._init_embeddings()
        return self._embeddings

    def _init_embeddings(self):
        """初始化 embedding 模型"""
        try:
            # 有 API Key 则用 ModelScope API，否则用本地 HuggingFace
            if settings.rag_embedding_api_key:
                logger.info("使用 ModelScope API 进行 embedding")
                return ModelScopeEmbeddings()
            else:
                logger.info("使用本地 HuggingFace 进行 embedding")
                from langchain_community.embeddings import HuggingFaceEmbeddings
                return HuggingFaceEmbeddings(
                    model_name=settings.rag_embedding_model,
                    model_kwargs={"device": "cpu"},
                    encode_kwargs={"normalize_embeddings": True},
                )
        except Exception as e:
            logger.error(f"Embedding 初始化失败: {e}")
            raise

    @property
    def vectorstore(self) -> Chroma:
        """延迟初始化 vectorstore"""
        if self._vectorstore is None:
            try:
                self._vectorstore = Chroma(
                    collection_name=self.collection_name,
                    embedding_function=self.embeddings,
                    persist_directory=self.persist_directory,
                )
                logger.info(f"VectorStore 初始化成功: {self.collection_name}")
            except Exception as e:
                logger.error(f"VectorStore 初始化失败: {e}")
                raise
        return self._vectorstore

    def add_documents(
        self,
        documents: List[Document],
        ids: Optional[List[str]] = None,
    ) -> List[str]:
        """添加文档到向量存储"""
        if not documents:
            return []
        try:
            result = self.vectorstore.add_documents(documents, ids=ids)
            logger.info(f"成功添加 {len(documents)} 个文档")
            return result
        except Exception as e:
            logger.error(f"添加文档失败: {e}")
            raise

    def delete(self, ids: Optional[List[str]] = None, where: Optional[Dict] = None):
        """删除文档"""
        try:
            if ids:
                self.vectorstore.delete(ids=ids)
            elif where:
                self.vectorstore.delete(where=where)
            else:
                # 清空整个 collection：删除整个目录
                import shutil
                if Path(self.persist_directory).exists():
                    shutil.rmtree(self.persist_directory, ignore_errors=True)
                # 强制重新创建，关闭旧的 client
                self._vectorstore = None
                self._embeddings = None
                logger.info(f"已清空向量库")
        except Exception as e:
            logger.error(f"删除文档失败: {e}")
            raise

    def similarity_search(
        self,
        query: str,
        k: Optional[int] = None,
        filter: Optional[Dict] = None,
    ) -> List[Document]:
        """相似度搜索"""
        k = k or rag_settings.top_k
        try:
            return self.vectorstore.similarity_search(query, k=k, filter=filter)
        except Exception as e:
            logger.error(f"相似度搜索失败: {e}")
            raise

    def similarity_search_with_score(
        self,
        query: str,
        k: Optional[int] = None,
        filter: Optional[Dict] = None,
    ) -> List[tuple[Document, float]]:
        """带分数的相似度搜索"""
        k = k or rag_settings.top_k
        try:
            return self.vectorstore.similarity_search_with_score(query, k=k, filter=filter)
        except Exception as e:
            logger.error(f"相似度搜索（带分数）失败: {e}")
            raise

    def as_retriever(
        self,
        search_type: str = "similarity",
        k: Optional[int] = None,
        filter: Optional[Dict] = None,
    ):
        """转为检索器"""
        k = k or rag_settings.top_k
        return self.vectorstore.as_retriever(
            search_type=search_type, search_kwargs={"k": k, "filter": filter}
        )

    def get_collection_stats(self) -> Dict[str, Any]:
        """获取集合统计信息"""
        try:
            count = self.vectorstore._collection.count()
            return {"collection_name": self.collection_name, "document_count": count}
        except Exception as e:
            logger.warning(f"获取集合统计失败: {e}")
            return {"collection_name": self.collection_name, "document_count": 0}


# 延迟初始化全局实例，避免导入时失败
_vector_store_manager: Optional[VectorStoreManager] = None


def get_vector_store_manager() -> VectorStoreManager:
    """获取全局 VectorStoreManager 实例（延迟初始化）"""
    global _vector_store_manager
    if _vector_store_manager is None:
        try:
            _vector_store_manager = VectorStoreManager()
            logger.info("VectorStoreManager 全局实例初始化成功")
        except Exception as e:
            logger.error(f"VectorStoreManager 全局实例初始化失败: {e}")
            raise
    return _vector_store_manager


# 向后兼容，直接访问时自动获取实例
vector_store_manager = None  # 不在导入时初始化
