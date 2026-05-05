from app.services.http_base import JavaBackendHttpClient


class IrrigationClient(JavaBackendHttpClient):
    """灌溉管理"""

    async def get_irrigation_logs(self, point_id: int | None = None) -> list[dict]:
        """获取灌溉记录"""
        if point_id is None:
            return await self._get("/irrigation/logs")
        return await self._get(f"/irrigation/logs?pointId={point_id}")

    async def get_irrigation_logs_paged(
        self,
        point_id: int | None = None,
        page: int = 0,
        size: int = 10,
    ) -> dict:
        """分页获取灌溉记录"""
        query = f"page={page}&size={size}"
        if point_id is not None:
            query = f"pointId={point_id}&{query}"
        return await self._get(f"/irrigation/logs/paged?{query}")

    async def get_latest_irrigation_log(self, point_id: int | None = None) -> dict:
        """获取最近灌溉记录"""
        if point_id is None:
            return await self._get("/irrigation/latest")
        return await self._get(f"/irrigation/latest?pointId={point_id}")

    async def get_irrigation_total(self, point_id: int | None = None) -> dict:
        """获取总灌溉水量"""
        if point_id is None:
            return await self._get("/irrigation/total")
        return await self._get(f"/irrigation/total?pointId={point_id}")

    async def get_auto_irrigation_plan(self, payload: dict) -> dict:
        """获取自动灌溉计划"""
        return await self._post("/irrigation/plan", payload)

    async def start_auto_irrigation(self, payload: dict) -> dict:
        """启动自动灌溉"""
        return await self._post("/irrigation/auto/start", payload)

    async def start_irrigation(self, payload: dict) -> dict:
        """开始灌溉"""
        return await self._post("/irrigation/start", payload)

    async def stop_irrigation(self, log_id: int) -> dict:
        """停止灌溉"""
        return await self._post("/irrigation/stop", {"logId": log_id})

    async def delete_irrigation_log(self, log_id: int) -> dict:
        """删除灌溉记录"""
        return await self._delete(f"/irrigation/{log_id}")
