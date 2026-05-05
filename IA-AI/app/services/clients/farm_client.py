from app.services.http_base import JavaBackendHttpClient


class FarmClient(JavaBackendHttpClient):
    """农场管理"""

    async def get_farm_list(self, user_id: int | None = None, active_only: bool = False) -> list[dict]:
        """获取农场列表"""
        query_parts: list[str] = [f"activeOnly={str(active_only).lower()}"]
        if user_id is not None:
            query_parts.append(f"userId={user_id}")
        query = "&".join(query_parts)
        return await self._get(f"/farm/list?{query}")

    async def get_farm_detail(self, farm_id: int) -> dict:
        """获取农场详情（含检测点列表）"""
        return await self._get(f"/farm/{farm_id}")

    async def get_farm_points(self, farm_id: int) -> list[dict]:
        """获取农场下检测点列表"""
        return await self._get(f"/farm/{farm_id}/points")

    async def create_farm(self, payload: dict) -> dict:
        """添加农场"""
        return await self._post("/farm", payload)

    async def update_farm(self, farm_id: int, payload: dict) -> dict:
        """更新农场"""
        return await self._put(f"/farm/{farm_id}", payload)

    async def delete_farm(self, farm_id: int) -> dict:
        """删除农场"""
        return await self._delete(f"/farm/{farm_id}")
