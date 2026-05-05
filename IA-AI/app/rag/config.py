from pydantic_settings import BaseSettings
from typing import Optional


class RAGSettings(BaseSettings):
    """RAG 配置类 - 仅包含 RAG 自身参数"""

    chunk_size: int = 500
    chunk_overlap: int = 50
    top_k: int = 5
    similarity_threshold: float = 0.1
    persist_dir: str = "./data/vectorstore"
    documents_dir: str = "./data/documents"
    rerank_enabled: bool = False
    rerank_model: Optional[str] = None

    class Config:
        env_prefix = "RAG_"
        extra = "ignore"


rag_settings = RAGSettings()