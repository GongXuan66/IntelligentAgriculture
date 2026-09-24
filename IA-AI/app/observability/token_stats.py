"""
Token 用量与耗时统计（可观测性）。

每次 /api/chat 流式请求结束后，从 on_chat_model_end 事件收集
usage_metadata（input/output/total tokens），聚合后：
- 追加写入 logs/token_usage.jsonl（逐条明细，可落库分析）
- 内存累计计数，通过 GET /api/stats 暴露
"""
import json
import logging
import os
import threading
import time
from pathlib import Path
from typing import Any, Optional

logger = logging.getLogger(__name__)

LOG_DIR = Path(os.getenv("TOKEN_LOG_DIR", "./logs"))
LOG_FILE = LOG_DIR / "token_usage.jsonl"


class TokenStats:
    """线程安全的用量聚合器"""

    def __init__(self):
        self._lock = threading.Lock()
        self._total_requests = 0
        self._total_input_tokens = 0
        self._total_output_tokens = 0
        self._total_duration_ms = 0.0
        self._by_model: dict[str, dict[str, Any]] = {}

    def record(
        self,
        *,
        session_id: str,
        model: str,
        input_tokens: int,
        output_tokens: int,
        duration_ms: float,
        path: str = "/api/chat",
    ):
        with self._lock:
            self._total_requests += 1
            self._total_input_tokens += input_tokens
            self._total_output_tokens += output_tokens
            self._total_duration_ms += duration_ms
            bucket = self._by_model.setdefault(
                model, {"requests": 0, "input_tokens": 0, "output_tokens": 0})
            bucket["requests"] += 1
            bucket["input_tokens"] += input_tokens
            bucket["output_tokens"] += output_tokens

        entry = {
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S"),
            "path": path,
            "session_id": session_id,
            "model": model,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "total_tokens": input_tokens + output_tokens,
            "duration_ms": round(duration_ms, 1),
        }
        try:
            LOG_DIR.mkdir(parents=True, exist_ok=True)
            with open(LOG_FILE, "a", encoding="utf-8") as f:
                f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        except Exception as e:
            logger.debug(f"token 日志写入失败: {e}")

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            avg_ms = (
                self._total_duration_ms / self._total_requests
                if self._total_requests else 0.0
            )
            return {
                "total_requests": self._total_requests,
                "total_input_tokens": self._total_input_tokens,
                "total_output_tokens": self._total_output_tokens,
                "total_tokens": self._total_input_tokens + self._total_output_tokens,
                "avg_duration_ms": round(avg_ms, 1),
                "by_model": dict(self._by_model),
            }


token_stats = TokenStats()


def extract_usage(event: dict) -> Optional[dict[str, Any]]:
    """从 astream_events 的 on_chat_model_end 事件提取 token 用量"""
    output = (event.get("data") or {}).get("output")
    usage = getattr(output, "usage_metadata", None)
    if not usage:
        return None
    metadata = event.get("metadata") or {}
    return {
        "model": metadata.get("ls_model_name") or "unknown",
        "input_tokens": int(usage.get("input_tokens", 0)),
        "output_tokens": int(usage.get("output_tokens", 0)),
    }
