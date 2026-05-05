from app.services.http_base import JavaBackendHttpClient


class DeviceClient(JavaBackendHttpClient):
    """设备管理"""

    async def get_device_list(self, point_id: int | None = None) -> list[dict]:
        """获取设备列表（可选 pointId）"""
        if point_id is None:
            return await self._get("/device/list")
        return await self._get(f"/device/list?pointId={point_id}")

    async def get_device_by_id(self, device_id: int) -> dict:
        """获取设备详情"""
        return await self._get(f"/device/{device_id}")

    async def get_device_status(self, device_code: str) -> dict:
        """获取设备状态"""
        return await self._get(f"/device/{device_code}/status")

    async def control_device(self, device_code: str, command: str) -> dict:
        """控制设备开关"""
        normalized = command.lower().strip()
        if normalized not in {"on", "off"}:
            raise ValueError("command must be 'on' or 'off'")

        payload = {"deviceCode": device_code, "command": normalized}
        return await self._post("/device/control", payload)

    async def create_device(self, payload: dict) -> dict:
        """添加设备"""
        return await self._post("/device", payload)

    async def delete_device(self, device_id: int) -> dict:
        """删除设备"""
        return await self._delete(f"/device/{device_id}")
