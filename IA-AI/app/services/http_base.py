import httpx
from typing import Any
from urllib.parse import urlsplit, urlunsplit
from app.config import settings


class JavaBackendHttpClient:
    """HTTP基础客户端，负责请求与统一响应解析"""

    def __init__(self):
        self.base_url = self._normalize_base_url(settings.java_backend_url)
        self.api_prefix = "/api"
        self.client = httpx.AsyncClient(timeout=30.0)

    async def close(self):
        await self.client.aclose()

    async def _get(self, path: str) -> Any:
        """GET请求辅助方法"""
        url = self._build_url(path)
        try:
            response = await self.client.get(url)
            response.raise_for_status()
            payload = response.json()
        except httpx.HTTPStatusError as exc:
            raise RuntimeError(
                f"GET {path} 失败，状态为{exc.response.status_code}: {exc.response.text}"
            ) from exc
        except httpx.RequestError as exc:
            raise RuntimeError(f"GET {path}请求错误: {exc}") from exc
        except ValueError as exc:
            raise RuntimeError(f"GET {path} 返回 non-JSON response") from exc

        return self._extract_data(payload, path)

    async def _post(self, path: str, payload: dict) -> Any:
        """POST请求辅助方法"""
        url = self._build_url(path)
        try:
            response = await self.client.post(url, json=payload)
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPStatusError as exc:
            raise RuntimeError(
                f"POST {path} 失败，状态为 {exc.response.status_code}: {exc.response.text}"
            ) from exc
        except httpx.RequestError as exc:
            raise RuntimeError(f"POST {path}请求错误: {exc}") from exc
        except ValueError as exc:
            raise RuntimeError(f"POST {path} 返回 non-JSON response") from exc

        return self._extract_data(body, path)

    async def _put(self, path: str, payload: dict) -> Any:
        """PUT请求辅助方法"""
        url = self._build_url(path)
        try:
            response = await self.client.put(url, json=payload)
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPStatusError as exc:
            raise RuntimeError(
                f"PUT {path} 失败，状态为 {exc.response.status_code}: {exc.response.text}"
            ) from exc
        except httpx.RequestError as exc:
            raise RuntimeError(f"PUT {path}请求错误: {exc}") from exc
        except ValueError as exc:
            raise RuntimeError(f"PUT {path} 返回 non-JSON response") from exc

        return self._extract_data(body, path)

    async def _delete(self, path: str) -> Any:
        """DELETE请求辅助方法"""
        url = self._build_url(path)
        try:
            response = await self.client.delete(url)
            response.raise_for_status()
            body = response.json()
        except httpx.HTTPStatusError as exc:
            raise RuntimeError(
                f"DELETE {path} 失败，状态为 {exc.response.status_code}: {exc.response.text}"
            ) from exc
        except httpx.RequestError as exc:
            raise RuntimeError(f"DELETE {path}请求错误: {exc}") from exc
        except ValueError as exc:
            raise RuntimeError(f"DELETE {path} 返回 non-JSON response") from exc

        return self._extract_data(body, path)

    def _extract_data(self, body: Any, path: str) -> Any:
        """统一解析Java后端返回结构，优先返回data字段。"""
        if not isinstance(body, dict):
            return body

        code = body.get("code")
        if code not in (None, 0, 200, "0", "200"):
            msg = body.get("msg") or body.get("message") or "unknown error"
            raise RuntimeError(f"API {path} business error, code={code}, msg={msg}")

        return body.get("data", body)

    def _normalize_base_url(self, base_url: str | None) -> str:
        raw = (base_url or "").strip().strip('"').strip("'")
        if not raw:
            raise RuntimeError("JAVA_BACKEND_URL 未配置")

        if not raw.startswith(("http://", "https://")):
            raw = f"http://{raw}"

        return raw.rstrip("/")

    def _build_url(self, path: str) -> str:
        parts = urlsplit(self.base_url)
        base_path = parts.path.rstrip("/")
        req_path = f"/{path.lstrip('/')}"

        if base_path != self.api_prefix and not req_path.startswith(f"{self.api_prefix}/"):
            req_path = f"{self.api_prefix}{req_path}"

        # If base_url already contains a path prefix like /api, avoid /api/api duplication.
        if base_path and req_path.startswith(f"{base_path}/"):
            req_path = req_path[len(base_path):]

        final_path = f"{base_path}{req_path}" if base_path else req_path
        return urlunsplit((parts.scheme, parts.netloc, final_path, "", ""))
