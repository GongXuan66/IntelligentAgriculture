from app.services.http_base import JavaBackendHttpClient


class TestClient(JavaBackendHttpClient):
    """测试接口"""

    async def test_all_smart_irrigation(self, point_id: int = 1) -> dict:
        """测试全部算法效果"""
        return await self._get(f"/test/smart-irrigation/all?pointId={point_id}")

    async def test_predict(self, point_id: int = 1, threshold: float = 40) -> dict:
        """测试EWMA湿度预测"""
        return await self._get(f"/test/smart-irrigation/predict?pointId={point_id}&threshold={threshold}")

    async def test_learning(self, point_id: int = 1) -> dict:
        """测试自适应学习效果"""
        return await self._get(f"/test/smart-irrigation/learning?pointId={point_id}")

    async def test_crop_stage(self, point_id: int = 1) -> dict:
        """测试作物生长阶段感知"""
        return await self._get(f"/test/smart-irrigation/crop?pointId={point_id}")

    async def test_set_crop(self, point_id: int, crop_code: str, planting_date: str) -> dict:
        """测试设置作物"""
        return await self._post(
            f"/test/smart-irrigation/crop?pointId={point_id}&cropCode={crop_code}&plantingDate={planting_date}",
            {},
        )

    async def test_generate_plan(
        self,
        point_id: int = 1,
        soil_moisture: float | None = None,
        temperature: float | None = None,
        threshold: int | None = None,
    ) -> dict:
        """测试生成智能灌溉计划"""
        query_parts = [f"pointId={point_id}"]
        if soil_moisture is not None:
            query_parts.append(f"soilMoisture={soil_moisture}")
        if temperature is not None:
            query_parts.append(f"temperature={temperature}")
        if threshold is not None:
            query_parts.append(f"threshold={threshold}")
        query = "&".join(query_parts)
        return await self._post(f"/test/smart-irrigation/plan?{query}", {})

    async def test_simulate_irrigation(self, point_id: int = 1, soil_moisture_before: float = 35) -> dict:
        """模拟智能灌溉流程"""
        return await self._post(
            f"/test/smart-irrigation/simulate?pointId={point_id}&soilMoistureBefore={soil_moisture_before}",
            {},
        )

    async def test_generate_history(self, point_id: int = 1, hours: int = 24, trend: str = "falling") -> dict:
        """生成传感器历史数据"""
        return await self._post(
            f"/test/smart-irrigation/generate-history?pointId={point_id}&hours={hours}&trend={trend}",
            {},
        )

    async def test_irrigation_history(self, point_id: int = 1, limit: int = 10) -> dict:
        """查看灌溉历史和学习效果"""
        return await self._get(f"/test/smart-irrigation/history?pointId={point_id}&limit={limit}")

    async def test_reset_learning(self, point_id: int = 1) -> dict:
        """重置学习参数"""
        return await self._post(f"/test/smart-irrigation/reset-learning?pointId={point_id}", {})

    async def test_optimization(
        self,
        current_moisture: float = 35,
        target_moisture: float = 55,
        temperature: float = 28,
        current_hour: int = 14,
        crop_factor: float = 1.0,
    ) -> dict:
        """测试多目标优化算法"""
        return await self._get(
            "/test/smart-irrigation/optimization"
            f"?currentMoisture={current_moisture}"
            f"&targetMoisture={target_moisture}"
            f"&temperature={temperature}"
            f"&currentHour={current_hour}"
            f"&cropFactor={crop_factor}"
        )

    async def test_optimization_info(self) -> dict:
        """获取优化算法信息"""
        return await self._get("/test/smart-irrigation/optimization/info")

    async def test_lstm(self, point_id: int = 1) -> dict:
        """测试LSTM模型预测"""
        return await self._get(f"/test/smart-irrigation/lstm?pointId={point_id}")

    async def test_compare_algorithms(self, current_moisture: float = 35, target_moisture: float = 55) -> dict:
        """获取算法对比报告"""
        return await self._get(
            f"/test/smart-irrigation/compare?currentMoisture={current_moisture}&targetMoisture={target_moisture}"
        )

    async def test_status(self) -> dict:
        """获取系统状态"""
        return await self._get("/test/status")

    async def test_ping(self) -> dict:
        """Ping 测试"""
        return await self._get("/test/ping")
