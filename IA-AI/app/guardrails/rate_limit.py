"""
AI 接口限流：IP / 会话 / 全局三级令牌桶。

内存实现，适用于单实例部署；多实例时把 BucketStore 替换为
Redis 的 INCR + EXPIRE 或 Lua 令牌桶即可（接口保持不变）。

限额通过环境变量配置：
    RATE_LIMIT_IP_PER_MIN      单 IP 每分钟请求数（默认 20）
    RATE_LIMIT_SESSION_PER_MIN 单会话每分钟请求数（默认 10）
    RATE_LIMIT_GLOBAL_PER_MIN  服务全局每分钟请求数（默认 120）
"""
import os
import threading
import time
from dataclasses import dataclass


def _env_int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except (TypeError, ValueError):
        return default


IP_PER_MIN = _env_int("RATE_LIMIT_IP_PER_MIN", 20)
SESSION_PER_MIN = _env_int("RATE_LIMIT_SESSION_PER_MIN", 10)
GLOBAL_PER_MIN = _env_int("RATE_LIMIT_GLOBAL_PER_MIN", 120)


class TokenBucket:
    """令牌桶：按恒定速率补充，突发不超过容量"""

    def __init__(self, rate_per_sec: float, capacity: int):
        self.rate = rate_per_sec
        self.capacity = capacity
        self.tokens = float(capacity)
        self.updated_at = time.monotonic()

    def allow(self) -> bool:
        now = time.monotonic()
        self.tokens = min(
            self.capacity,
            self.tokens + (now - self.updated_at) * self.rate,
        )
        self.updated_at = now
        if self.tokens >= 1.0:
            self.tokens -= 1.0
            return True
        return False


@dataclass(frozen=True)
class RateLimitVerdict:
    allowed: bool
    reason: str = ""
    scope: str = ""


class RateLimiter:
    """三级令牌桶限流器（线程安全，桶懒创建、定期清理）"""

    def __init__(self):
        self._lock = threading.Lock()
        self._buckets: dict[str, TokenBucket] = {}
        self._last_cleanup = time.monotonic()

    def _bucket(self, key: str, per_min: int) -> TokenBucket:
        bucket = self._buckets.get(key)
        if bucket is None:
            bucket = TokenBucket(rate_per_sec=per_min / 60.0, capacity=per_min)
            self._buckets[key] = bucket
        return bucket

    def _cleanup_stale(self):
        """清理 10 分钟未活跃的非全局桶，防止内存膨胀"""
        now = time.monotonic()
        if now - self._last_cleanup < 60:
            return
        self._last_cleanup = now
        stale = [
            k for k, b in self._buckets.items()
            if k != "global" and now - b.updated_at > 600
        ]
        for k in stale:
            self._buckets.pop(k, None)

    def check(self, ip: str, session_id: str) -> RateLimitVerdict:
        with self._lock:
            self._cleanup_stale()
            if not self._bucket("global", GLOBAL_PER_MIN).allow():
                return RateLimitVerdict(False, "服务繁忙，请稍后再试", "global")
            if not self._bucket(f"ip:{ip}", IP_PER_MIN).allow():
                return RateLimitVerdict(
                    False, f"请求过于频繁（单IP限 {IP_PER_MIN} 次/分钟）", "ip")
            if not self._bucket(f"session:{session_id}", SESSION_PER_MIN).allow():
                return RateLimitVerdict(
                    False, f"会话请求过于频繁（限 {SESSION_PER_MIN} 次/分钟）", "session")
        return RateLimitVerdict(True)


rate_limiter = RateLimiter()
