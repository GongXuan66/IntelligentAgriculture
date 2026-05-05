from app.services.http_base import JavaBackendHttpClient


class WeatherClient(JavaBackendHttpClient):
    """天气"""

    async def get_current_weather(self, latitude: float, longitude: float) -> dict:
        """根据经纬度获取天气"""
        return await self._get(f"/weather/current?latitude={latitude}&longitude={longitude}")
