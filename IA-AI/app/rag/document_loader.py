from pathlib import Path
from typing import List, Optional
from langchain_community.document_loaders import (
    TextLoader,
    PyPDFLoader,
)
from langchain_core.documents import Document
from app.rag.config import rag_settings


class DocumentLoader:
    """文档加载器"""

    def __init__(self, encoding: str = "utf-8"):
        self.encoding = encoding
        self.documents_dir = Path(rag_settings.documents_dir)

    def load_file(self, file_path: str) -> List[Document]:
        """加载单个文件"""
        path = Path(file_path)
        suffix = path.suffix.lower()

        loaders = {
            ".txt": TextLoader,
            ".md": TextLoader,
            ".markdown": TextLoader,
            ".pdf": PyPDFLoader,
        }

        loader_class = loaders.get(suffix)
        if not loader_class:
            raise ValueError(f"Unsupported file type: {suffix}")

        if suffix == ".pdf":
            loader = loader_class(str(path))
        else:
            loader = loader_class(str(path), encoding=self.encoding)

        return loader.load()

    def load_directory(
        self,
        directory: Optional[str] = None,
        glob_pattern: str = "**/*",
    ) -> List[Document]:
        """加载目录下的所有文档"""
        dir_path = Path(directory) if directory else self.documents_dir

        if not dir_path.exists():
            return []

        documents = []
        supported_suffixes = {".md", ".txt", ".markdown", ".pdf"}

        for file_path in dir_path.rglob("*"):
            if not file_path.is_file():
                continue
            if file_path.suffix.lower() not in supported_suffixes:
                continue

            documents.extend(self.load_file(str(file_path)))

        return documents



document_loader = DocumentLoader()