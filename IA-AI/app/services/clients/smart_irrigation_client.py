from app.services.http_base import JavaBackendHttpClient


class SmartIrrigationClient(JavaBackendHttpClient):
    """智能灌溉"""

    async def get_smart_irrigation_plan(self, payload: dict | None = None, point_id: int | None = None) -> dict:
        """获取智能灌溉计划"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._post(f"/smart-irrigation/plan{query}", payload or {})

    async def execute_smart_irrigation(self, payload: dict, point_id: int | None = None) -> dict:
        """执行智能灌溉"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._post(f"/smart-irrigation/execute{query}", payload)

    async def complete_smart_irrigation(self, log_id: int, soil_moisture_after: float) -> dict:
        """灌溉完成回调"""
        return await self._post(
            f"/smart-irrigation/complete/{log_id}?soilMoistureAfter={soil_moisture_after}",
            {},
        )

    async def predict_moisture(self, point_id: int | None = None, hours_ahead: int = 4) -> dict:
        """获取湿度预测"""
        query = f"hoursAhead={hours_ahead}"
        if point_id is not None:
            query = f"pointId={point_id}&{query}"
        return await self._get(f"/smart-irrigation/predict?{query}")

    async def analyze_moisture_prediction(self, point_id: int | None = None, threshold: float = 40) -> dict:
        """分析是否需要预防性灌溉"""
        query = f"threshold={threshold}"
        if point_id is not None:
            query = f"pointId={point_id}&{query}"
        return await self._get(f"/smart-irrigation/predict/analyze?{query}")

    async def get_learning_progress(self, point_id: int | None = None) -> dict:
        """获取学习进度"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._get(f"/smart-irrigation/learning/progress{query}")

    async def get_learned_params(self, point_id: int | None = None) -> dict:
        """获取学习到的参数"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._get(f"/smart-irrigation/learning/params{query}")

    async def get_irrigation_strategy(self, point_id: int | None = None) -> dict:
        """获取当前灌溉策略"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._get(f"/smart-irrigation/strategy{query}")

    async def set_crop_info(self, payload: dict, point_id: int | None = None) -> dict:
        """设置作物信息"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._post(f"/smart-irrigation/crop{query}", payload)

    async def harvest_crop(self, point_id: int | None = None) -> dict:
        """收获作物"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._delete(f"/smart-irrigation/crop{query}")

    async def get_crop_stage_configs(self, crop_type: str) -> dict:
        """获取作物阶段配置"""
        return await self._get(f"/smart-irrigation/crop/stages?cropType={crop_type}")

    async def get_supported_crop_types(self) -> dict:
        """获取支持的作物类型"""
        return await self._get("/smart-irrigation/crop/types")

    async def get_smart_irrigation_stats(self, point_id: int | None = None) -> dict:
        """获取智能灌溉统计"""
        query = f"?pointId={point_id}" if point_id is not None else ""
        return await self._get(f"/smart-irrigation/stats{query}")
