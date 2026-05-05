from typing import List, Optional
from langchain_text_splitters import (
    RecursiveCharacterTextSplitter,
    MarkdownTextSplitter,
    PythonCodeTextSplitter,
)
from langchain_core.documents import Document
from app.rag.config import rag_settings


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
        )

        self.markdown_splitter = MarkdownTextSplitter(
            chunk_size=self.chunk_size,
            chunk_overlap=self.chunk_overlap,
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
            return self.markdown_splitter.split_documents(documents)

        return self.recursive_splitter.split_documents(documents)

    # 备用入口，不一定有用，正常流程都走document的分词器
    def split_text(self, text: str, splitter_type: str = "recursive") -> List[str]:
        """分块文本"""
        if splitter_type == "markdown":
            return self.markdown_splitter.split_text(text)

        return self.recursive_splitter.split_text(text)


text_splitter = TextSplitter()