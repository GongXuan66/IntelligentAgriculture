from app.services.http_base import JavaBackendHttpClient


class MonitorPointClient(JavaBackendHttpClient):
    """检测点管理"""

    async def get_monitor_point_list(
        self,
        active_only: bool = False,
        farm_id: int | None = None,
    ) -> list[dict]:
        """获取检测点列表"""
        query_parts = [f"activeOnly={str(active_only).lower()}"]
        if farm_id is not None:
            query_parts.append(f"farmId={farm_id}")
        query = "&".join(query_parts)
        return await self._get(f"/point/list?{query}")

    async def get_monitor_point_by_id(self, point_id: int) -> dict:
        """获取检测点详情"""
        return await self._get(f"/point/{point_id}")

    async def create_monitor_point(self, payload: dict) -> dict:
        """添加检测点"""
        return await self._post("/point", payload)

    async def update_monitor_point(self, point_id: int, payload: dict) -> dict:
        """更新检测点"""
        return await self._put(f"/point/{point_id}", payload)

    async def delete_monitor_point(self, point_id: int) -> dict:
        """删除检测点"""
        return await self._delete(f"/point/{point_id}")
