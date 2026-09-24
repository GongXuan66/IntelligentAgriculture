from typing import List, Optional
from langchain_text_splitters import (
    RecursiveCharacterTextSplitter,
    MarkdownTextSplitter,
    MarkdownHeaderTextSplitter,
    PythonCodeTextSplitter,
)
from langchain_core.documents import Document
from app.rag.config import rag_settings

# Markdown 标题层级 -> metadata 键名
HEADERS_TO_SPLIT_ON = [
    ("#", "h1"),
    ("##", "h2"),
    ("###", "h3"),
    ("####", "h4"),
]


class TextSplitter:
    """文本分块器"""

    def __init__(
        self,
        chunk_size: Optional[int] = None,
        chunk_overlap: Optional[int] = None,
    ):
        self.chunk_size = chunk_size or rag_settings.chunk_size # 块大小
        self.chunk_overlap = chunk_overlap or rag_settings.chunk_overlap #重叠大小

        self.recursive_splitter = RecursiveCharacterTextSplitter(
            chunk_size=self.chunk_size,
            chunk_overlap=self.chunk_overlap,
            length_function=len,  #测量块的字符数
            separators=["\n\n", "\n", "。", ".", " ", ""],  #分割符号
            keep_separator=True,  # 保留句末标点，避免语义截断
        )

        self.markdown_splitter = MarkdownTextSplitter(
            chunk_size=self.chunk_size,
            chunk_overlap=self.chunk_overlap,
        )

        # 按标题层级切分（标题写入 metadata，供来源标注与同源分块补全使用）
        self.header_splitter = MarkdownHeaderTextSplitter(
            headers_to_split_on=HEADERS_TO_SPLIT_ON,
            strip_headers=False,  # 标题保留在正文内，利于 embedding 语义完整
        )

    def split_documents(
        self,
        documents: List[Document], #通过文档加载器得到的documents列表
        splitter_type: str = "recursive",
    ) -> List[Document]:
        """分块文档"""
        if not documents:
            return []

        if splitter_type == "markdown":
            return self._split_markdown_with_headers(documents)

        return self.recursive_splitter.split_documents(documents)

    def _split_markdown_with_headers(self, documents: List[Document]) -> List[Document]:
        """Markdown 两阶段切分：先按标题层级切（标题路径写入 metadata），
        超过 chunk_size 的标题块再用递归切分细化（metadata 随之保留）。"""
        results: List[Document] = []
        for doc in documents:
            header_chunks = self.header_splitter.split_text(doc.page_content)
            for chunk in header_chunks:
                # 保留加载器写入的 source 等原始 metadata
                merged = dict(doc.metadata)
                merged.update(chunk.metadata)
                chunk.metadata = merged
            results.extend(self.recursive_splitter.split_documents(header_chunks))
        return results

    # 备用入口，不一定有用，正常流程都走document的分词器
    def split_text(self, text: str, splitter_type: str = "recursive") -> List[str]:
        """分块文本"""
        if splitter_type == "markdown":
            return self.markdown_splitter.split_text(text)

        return self.recursive_splitter.split_text(text)


text_splitter = TextSplitter()