from app.services.clients.ai_client import AiClient
from app.services.clients.alarm_client import AlarmClient
from app.services.clients.device_client import DeviceClient
from app.services.clients.environment_client import EnvironmentClient
from app.services.clients.farm_client import FarmClient
from app.services.clients.irrigation_client import IrrigationClient
from app.services.clients.monitor_point_client import MonitorPointClient
from app.services.clients.smart_irrigation_client import SmartIrrigationClient
from app.services.clients.test_client import TestClient
from app.services.clients.weather_client import WeatherClient


class JavaBackendClient(
    DeviceClient,
    EnvironmentClient,
    IrrigationClient,
    AlarmClient,
    MonitorPointClient,
    FarmClient,
    WeatherClient,
    SmartIrrigationClient,
    AiClient,
    TestClient,
):
    """HTTP调用Java后端API"""



java_client = JavaBackendClient()
