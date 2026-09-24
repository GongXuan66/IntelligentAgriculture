"""输入 / 输出护轨（Guardrail）。

- input_guard: Prompt 注入特征 + 越权敏感指令规则拦截，在 chat 入口接入
- output_guard: 工具执行结果校验与失败自动重试包装
"""
from app.guardrails.input_guard import GuardrailResult, check_input
from app.guardrails.output_guard import is_error_result, wrap_tool_with_retry

__all__ = [
    "GuardrailResult",
    "check_input",
    "is_error_result",
    "wrap_tool_with_retry",
]
