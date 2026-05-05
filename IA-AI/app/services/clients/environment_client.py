from app.services.http_base import JavaBackendHttpClient


class EnvironmentClient(JavaBackendHttpClient):
    """环境监测"""

    async def get_current_environment(self, point_id: int | None = None) -> dict:
        """获取当前环境数据"""
        if point_id is None:
            return await self._get("/environment")
        return await self._get(f"/environment?pointId={point_id}")

    async def get_history_environment(self, point_id: int | None = None, limit: int = 100) -> list[dict]:
        """获取历史环境数据"""
        if point_id is None:
            return await self._get(f"/environment/history?limit={limit}")
        return await self._get(f"/environment/history?pointId={point_id}&limit={limit}")

    async def get_history_environment_paged(
        self,
        point_id: int | None = None,
        page: int = 0,
        size: int = 20,
    ) -> dict:
        """分页获取历史环境数据"""
        query = f"page={page}&size={size}"
        if point_id is not None:
            query = f"pointId={point_id}&{query}"
        return await self._get(f"/environment/history/paged?{query}")

    async def get_history_environment_range(
        self,
        start_time: str,
        end_time: str,
        point_id: int | None = None,
    ) -> list[dict]:
        """按时间范围查询历史环境数据"""
        query = f"startTime={start_time}&endTime={end_time}"
        if point_id is not None:
            query = f"pointId={point_id}&{query}"
        return await self._get(f"/environment/history/range?{query}")

    async def upload_environment_data(self, payload: dict) -> dict:
        """上报环境数据（网关用）"""
        return await self._post("/environment", payload)
