from typing import Any
from app.services.http_base import JavaBackendHttpClient


class AiClient(JavaBackendHttpClient):
    """AI 助手"""

    async def ai_chat_sync(self, payload: dict) -> dict:
        """AI对话（同步）"""
        return await self._post("/ai/chat", payload)

    async def ai_chat_stream(self, message: str, session_id: str | None = None) -> Any:
        """AI对话（流式）"""
        query = f"message={message}"
        if session_id:
            query = f"{query}&sessionId={session_id}"
        return await self._get(f"/ai/chat/stream?{query}")

    async def ai_chat_history(self, session_id: str) -> list[dict]:
        """获取对话历史"""
        return await self._get(f"/ai/history?sessionId={session_id}")

    async def ai_clear_memory(self, session_id: str) -> dict:
        """清除对话记忆"""
        return await self._delete(f"/ai/memory?sessionId={session_id}")
