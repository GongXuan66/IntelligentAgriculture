"""
模型分级路由：简单意图走小模型，复杂任务走主模型。

路由规则（纯本地规则，零额外 LLM 调用）：
- 简单意图（闲聊问候、单点状态查询、天气）-> 小模型（OPENAI_SMALL_MODEL，
  如 Qwen-Turbo）；未配置小模型时全部走主模型
- 其余（多步推理、专家咨询、农事建议、写操作）-> 主模型（Kimi-K2.5）

原则"宁错杀不放过"的反向：宁可把简单请求发给主模型（只是贵一点），
也不能把复杂请求错发给小模型（会答错），所以简单意图的白名单收得很窄。
"""
import logging
import re
from typing import Optional

from langchain_openai import ChatOpenAI

from app.config import settings

logger = logging.getLogger(__name__)

# 闲聊问候（无工具需求）
_CHITCHAT = re.compile(
    r"^(你好|您好|hi|hello|嗨|在吗|早上好|晚上好|谢谢|感谢|再见|拜拜)[!！。~～\s]*$",
    re.IGNORECASE,
)

# 天气查询（单工具单轮即可完成）
_WEATHER = re.compile(r"天气|气温|下雨|降雪|天气预报")

# 单点状态查询：句式短且只问一个读数
_SIMPLE_QUERY = re.compile(
    r"^(查(一?下|看)?|告诉我|现在)?[^。？?]{0,20}"
    r"(温度|湿度|光照|CO2|二氧化碳|土壤湿度|墒情)"
    r"(是?多少|怎么样|如何)?[？?\s]*$"
)

_small_llm: Optional[ChatOpenAI] = None


def get_small_llm() -> Optional[ChatOpenAI]:
    """小模型实例（懒加载）；未配置 OPENAI_SMALL_MODEL 时返回 None"""
    global _small_llm
    if _small_llm is not None:
        return _small_llm
    model = getattr(settings, "openai_small_model", None)
    if not model:
        return None
    _small_llm = ChatOpenAI(
        model=model,
        api_key=settings.openai_api_key,
        base_url=settings.openai_api_url,
        temperature=0.3,
        streaming=True,
    )
    logger.info(f"小模型路由已启用: {model}")
    return _small_llm


def is_simple_intent(message: str) -> bool:
    """判断是否为可交给小模型的简单意图（保守白名单）"""
    text = message.strip()
    if len(text) > 50:
        return False
    if _CHITCHAT.match(text):
        return True
    if _WEATHER.search(text) and len(text) <= 20:
        return True
    if _SIMPLE_QUERY.match(text):
        return True
    return False


def route_model(message: str, main_llm: ChatOpenAI) -> ChatOpenAI:
    """按意图选择模型；无法判定时一律回退主模型"""
    small = get_small_llm()
    if small is not None and is_simple_intent(message):
        logger.info(f"模型路由: 小模型 <- '{message[:20]}'")
        return small
    return main_llm
