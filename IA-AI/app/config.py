from pydantic_settings import BaseSettings
from typing import Optional
import os
from pathlib import Path
from dotenv import load_dotenv

# 加载.env文件，从当前文件所在目录查找
env_path = Path(__file__).parent / ".env"
load_dotenv(dotenv_path=str(env_path))

class Settings(BaseSettings):
    """
    配置类，使用pydantic进行数据验证和管理
    """
    #LLM配置
    openai_api_key: str = os.getenv("OPENAI_API_KEY")
    openai_api_url: str = os.getenv("OPENAI_API_URL")
    openai_model: str = os.getenv("OPENAI_MODEL")

    #java后端配置
    java_backend_url: str = os.getenv("JAVA_BACKEND_URL")

    # RAG Embedding 配置
    rag_embedding_model: str = os.getenv("RAG_EMBEDDING_MODEL")
    rag_embedding_api_key: Optional[str] = os.getenv("RAG_EMBEDDING_API_KEY")
    rag_embedding_base_url: str = os.getenv("RAG_EMBEDDING_BASE_URL", "https://api-inference.modelscope.cn/v1")


    #服务配置
    host:str = "localhost"
    port:str = "8000"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()