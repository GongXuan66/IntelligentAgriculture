"""
重建 RAG 向量索引（余弦距离）
=============================

背景：
    旧索引使用 Chroma 默认 L2 距离，`1 - score` 不是余弦相似度，
    导致阈值过滤失效。代码已改为创建 collection 时指定
    `hnsw:space=cosine`，但该元数据只在创建时生效，
    因此必须清空旧索引并重建。

运行前提（二选一）：
    1. 配置 ModelScope Embedding API（无需本地深度学习依赖）：
       在 app/.env 中设置
           RAG_EMBEDDING_API_KEY=<你的 ModelScope Token>
           RAG_EMBEDDING_MODEL=BAAI/bge-small-zh-v1.5
    2. 或安装可选的本地 embedding 依赖（间接依赖 torch，建议独显机器）：
           uv sync --extra local-embed
       （自动降级为本地 HuggingFace 模型）。

使用方法：
    cd IA-AI
    python scripts/rebuild_index.py
"""

import sys
from pathlib import Path

# 将项目根目录加入 import 路径
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.rag.pipeline import rag_pipeline  # noqa: E402
from app.rag.config import rag_settings  # noqa: E402


def main():
    print("=" * 50)
    print("重建 RAG 向量索引（hnsw:space=cosine）")
    print(f"文档目录: {rag_settings.documents_dir}")
    print(f"向量库目录: {rag_settings.persist_dir}")
    print("=" * 50)

    result = rag_pipeline.rebuild_index()

    print(f"状态: {result['status']}")
    if result["status"] == "success":
        print(f"索引文档数: {result['indexed_documents']}")
        print(f"索引文本块数: {result['indexed_chunks']}")
        print("索引已按余弦距离重建完成。")
    else:
        print(f"重建失败: {result.get('message', '未知错误')}")
        sys.exit(1)


if __name__ == "__main__":
    main()
