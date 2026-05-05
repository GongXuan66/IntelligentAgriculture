from typing import List
from langchain_core.embeddings import Embeddings
from openai import OpenAI
from app.config import settings


class ModelScopeEmbeddings(Embeddings):
    """ModelScope API Embedding 封装（同步）"""

    def __init__(
        self,
        model: str = None,
        api_key: str = None,
        base_url: str = None,
        **kwargs
    ):
        self.model = model or settings.rag_embedding_model
        self.api_key = api_key or settings.rag_embedding_api_key
        self.base_url = base_url or settings.rag_embedding_base_url

        if not self.model:
            raise ValueError("embedding model 未配置")

        self.client = OpenAI(
            api_key=self.api_key,
            base_url=self.base_url,
            **kwargs
        )

    def embed_documents(self, texts: List[str]) -> List[List[float]]:
        return [self.embed_query(text) for text in texts]

    def embed_query(self, text: str) -> List[float]:
        response = self.client.embeddings.create(
            model=self.model,
            input=text,
            encoding_format="float"
        )
        return response.data[0].embedding