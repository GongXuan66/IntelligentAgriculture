"""
输入侧护轨：Prompt 注入特征 + 越权敏感指令的规则拦截。

定位：低成本的第一道防线（正则规则，零 LLM 调用），拦不住所有攻击，
但能挡住常见注入模板和明显的越权请求；深度防护仍依赖
只读专家隔离 + 高危写操作人工确认。
"""
import re
from dataclasses import dataclass
from typing import Optional

# Prompt 注入特征（忽略大小写）
INJECTION_PATTERNS = [
    r"忽略(之前|以上|上述|所有).{0,12}(指令|提示|要求|规则)",
    r"ignore\s+(all\s+)?(previous|above|prior)\s+(instructions?|prompts?|rules?)",
    r"(输出|泄露|透露|告诉我).{0,8}(系统提示|提示词|system\s*prompt)",
    r"(jailbreak|越狱|开发者模式|DAN\s*模式)",
    r"扮演.{0,8}(无限制|不受限|没有限制)",
    r"你(现在)?不是.{0,6}(助手|AI).{0,10}(而是|是)",
]

# 越权 / 高危敏感指令
SENSITIVE_PATTERNS = [
    r"(删除|清空|重置|销毁).{0,8}(数据库|数据表|所有数据|全部数据|向量库)",
    # 宾语前置语序："把数据库删除" / "数据库全部删掉"
    r"(数据库|数据表|所有数据|全部数据|向量库).{0,8}(删除|清空|重置|销毁|删掉)",
    r"(drop\s+table|truncate\s+table|rm\s+-rf|delete\s+from)",
    r"(查看|获取|告诉我|输出).{0,8}(密码|口令|api[\s_-]?key|令牌|token|密钥)",
    r"(绕过|跳过|取消).{0,8}(人工确认|审批|确认流程)",
]

_COMPILED_INJECTION = [re.compile(p, re.IGNORECASE) for p in INJECTION_PATTERNS]
_COMPILED_SENSITIVE = [re.compile(p, re.IGNORECASE) for p in SENSITIVE_PATTERNS]


@dataclass(frozen=True)
class GuardrailResult:
    allowed: bool
    reason: Optional[str] = None
    category: Optional[str] = None  # injection / sensitive


def check_input(text: str) -> GuardrailResult:
    """
    检查用户输入是否命中拦截规则。

    Returns:
        GuardrailResult，allowed=False 时带 reason 和 category
    """
    if not text or not text.strip():
        return GuardrailResult(allowed=False, reason="输入内容为空", category="sensitive")

    for pattern in _COMPILED_INJECTION:
        if pattern.search(text):
            return GuardrailResult(
                allowed=False,
                reason="检测到疑似提示词注入指令，已拦截",
                category="injection",
            )

    for pattern in _COMPILED_SENSITIVE:
        if pattern.search(text):
            return GuardrailResult(
                allowed=False,
                reason="检测到越权或高危操作请求，已拦截",
                category="sensitive",
            )

    return GuardrailResult(allowed=True)
