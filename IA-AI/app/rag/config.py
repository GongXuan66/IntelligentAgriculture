from pydantic_settings import BaseSettings
from typing import Optional


class RAGSettings(BaseSettings):
    """RAG 配置类 - 仅包含 RAG 自身参数"""

    chunk_size: int = 500
    chunk_overlap: int = 50
    top_k: int = 5
    # 余弦相似度阈值（collection 已配置 hnsw:space=cosine，score 为 1-余弦距离）。
    # 0.5 为宽松起点，索引重建后按实测分布上调（预计 0.5~0.7）。
    similarity_threshold: float = 0.5
    # 过滤无意义短块的最小字符数（去除空白后）
    min_chunk_length: int = 10
    persist_dir: str = "./data/vectorstore"
    documents_dir: str = "./data/documents"

    # ---------- 混合检索（BM25 + 向量 + RRF） ----------
    hybrid_enabled: bool = True
    # 混合模式下向量粗召回的宽松阈值（最终排序交给 RRF）
    hybrid_vector_threshold: float = 0.3
    # 各路候选数量（粗召回）
    candidate_k: int = 10
    # RRF 倒数排名融合常数
    rrf_k: int = 60

    # ---------- Query 侧优化 ----------
    # 多轮指代改写（检测到"它/这个/那块地"等指代词时才调用 LLM）
    coref_enabled: bool = True
    # Multi-Query：用小模型改写多条检索 query
    multi_query_enabled: bool = True
    # 农业领域同义词扩展（纯规则，无 LLM 成本）
    synonym_enabled: bool = True
    # Query 改写使用的模型（None 则用主模型；可配便宜小模型如 Qwen-Turbo）
    query_rewrite_model: Optional[str] = None
    # 单轮检索的最大 query 数上限（原 query + 改写 + 同义词扩展）
    max_queries: int = 6

    # ---------- 同源分块补全 ----------
    # 命中分块后回填同文档前后各 neighbor_window 个相邻块
    neighbor_expand: bool = True
    neighbor_window: int = 1

    # ---------- Rerank 精排 ----------
    # 默认关闭：需要 sentence-transformers（torch）+ 本地模型下载。
    # 粗召回 candidate_k 条后精排取 rerank_top_n 条。
    rerank_enabled: bool = False
    rerank_model: Optional[str] = "BAAI/bge-reranker-base"
    rerank_top_n: int = 3

    class Config:
        env_prefix = "RAG_"
        extra = "ignore"


rag_settings = RAGSettings()