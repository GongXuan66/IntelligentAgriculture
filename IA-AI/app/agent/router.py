from dataclasses import dataclass


@dataclass(frozen=True)
class RouteResult:
    domains: tuple[str, ...]


KEYWORDS: dict[str, tuple[str, ...]] = {
    "device": ("设备", "继电器", "开关", "风机", "水泵", "阀门"),
    "environment": ("环境", "温度", "湿度", "光照", "土壤", "CO2"),
    "irrigation": ("灌溉", "浇水", "水量", "开始灌溉", "停止灌溉"),
    "alarm": ("报警", "告警", "异常"),
    "monitor": ("检测点", "监测点"),
    "weather": ("天气", "预报"),
}


def route_domains(message: str) -> RouteResult:
    text = message.lower()
    matched = []
    for domain, keywords in KEYWORDS.items():
        if any(keyword in text for keyword in keywords):
            matched.append(domain)

    if not matched:
        matched.append("device")

    return RouteResult(domains=tuple(dict.fromkeys(matched)))
