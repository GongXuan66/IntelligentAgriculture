from langchain_core.tools import tool
from app.services.http_client import java_client
import json

@tool(description="获取天气预报信息。")
async def get_weather(latitude: float, longitude: float) -> str:
    """
    获取天气预报信息
    :param latitude:
    :param longitude:
    :return: json字符串
    """
    try:
        weather = await java_client.get_current_weather(latitude, longitude)
        return json.dumps(weather, ensure_ascii=False, indent=2)
    except Exception as e:
        return json.dumps({"error": str(e)}, ensure_ascii=False, indent=2)
