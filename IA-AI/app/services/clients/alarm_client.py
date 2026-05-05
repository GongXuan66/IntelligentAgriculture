from app.services.http_base import JavaBackendHttpClient


class AlarmClient(JavaBackendHttpClient):
    """报警管理"""

    async def get_alarm_list(self, point_id: int | None = None, status: int | None = None) -> list[dict]:
        """获取报警列表"""
        query_parts: list[str] = []
        if point_id is not None:
            query_parts.append(f"pointId={point_id}")
        if status is not None:
            query_parts.append(f"status={status}")
        query = "&".join(query_parts)
        return await self._get(f"/alarm/list{('?' + query) if query else ''}")

    async def get_alarm_list_paged(self, page: int = 0, size: int = 10) -> dict:
        """分页获取报警列表"""
        return await self._get(f"/alarm/list/paged?page={page}&size={size}")

    async def get_unprocessed_alarm_count(self, point_id: int | None = None) -> dict:
        """获取未处理报警数量"""
        if point_id is None:
            return await self._get("/alarm/unprocessed/count")
        return await self._get(f"/alarm/unprocessed/count?pointId={point_id}")

    async def get_alarm_by_id(self, alarm_id: int) -> dict:
        """获取报警详情"""
        return await self._get(f"/alarm/{alarm_id}")

    async def handle_alarm(self, alarm_id: int, remark: str | None = None) -> dict:
        """处理报警"""
        payload = {} if remark is None else {"remark": remark}
        return await self._put(f"/alarm/{alarm_id}/handle", payload)

    async def handle_all_alarms_by_point(self, point_id: int) -> dict:
        """处理检测点所有报警"""
        return await self._put(f"/alarm/handle-all?pointId={point_id}", {})

    async def delete_alarm(self, alarm_id: int) -> dict:
        """删除报警记录"""
        return await self._delete(f"/alarm/{alarm_id}")
