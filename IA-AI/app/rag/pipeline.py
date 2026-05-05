from typing import List, Optional, Dict, Any
from pathlib import Path
from langchain_core.documents import Document
from app.rag.document_loader import document_loader
from app.rag.text_splitter import text_splitter
from app.rag.vector_store import VectorStoreManager
from app.rag.config import rag_settings


class RAGPipeline:
    """RAG 管道：文档加载 -> 分块 -> 向量化 -> 存储"""

    def __init__(
        self,
        collection_name: str = "default",
        vector_store: Optional[VectorStoreManager] = None,
    ):
        self.vector_store = vector_store or VectorStoreManager(collection_name=collection_name)

    def index_documents(
        self,
        documents: Optional[List[Document]] = None,
        directory: Optional[str] = None,
        rebuild: bool = False,
    ) -> Dict[str, Any]:
        """
        索引文档

        Args:
            documents: 文档列表（可选）
            directory: 文档目录（可选）
            rebuild: 是否重建索引（清空现有数据）

        Returns:
            索引结果统计
        """
        if rebuild:
            # 清空整个 collection
            self.vector_store.delete(where={})

        if documents is None:
            docs = document_loader.load_directory(directory)
        else:
            docs = documents

        if not docs:
            return {
                "status": "warning",
                "message": "No documents found",
                "indexed_documents": 0,
                "indexed_chunks": 0,
            }

        chunks = text_splitter.split_documents(docs)

        if not chunks:
            return {
                "status": "error",
                "message": "Failed to split documents",
                "indexed_documents": 0,
                "indexed_chunks": 0,
            }

        for i, chunk in enumerate(chunks):
            if "source" not in chunk.metadata:
                chunk.metadata["source"] = "unknown"
            chunk.metadata["chunk_id"] = f"chunk_{i}"

        ids = self.vector_store.add_documents(chunks)

        return {
            "status": "success",
            "indexed_documents": len(docs),
            "indexed_chunks": len(chunks),
            "chunk_ids": ids[:10],
        }

    def rebuild_index(self, directory: Optional[str] = None) -> Dict[str, Any]:
        """重建索引"""
        return self.index_documents(directory=directory, rebuild=True)

    def get_stats(self) -> Dict[str, Any]:
        """获取索引统计信息"""
        return self.vector_store.get_collection_stats()


rag_pipeline = RAGPipeline()