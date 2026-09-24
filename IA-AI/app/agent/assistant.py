from typing import Optional
from langchain_openai import ChatOpenAI
from langchain_core.runnables import RunnableConfig
from langchain.agents import create_agent
from langchain_core.tools import tool

from app.config import settings
from app.agent.tool_registry import get_tools_for_domains
from app.agent.experts.registry import EXPERTS
from app.agent.hitl import (
    control_device,
    start_irrigation,
    stop_irrigation,
    handle_alarm,
)
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver


# PostgreSQL 连接地址
DB_URI = "postgresql://postgres:postgres@localhost:5432/ia_ai"

_checkpointer: Optional[AsyncPostgresSaver] = None


def set_checkpointer(checkpointer: Optional[AsyncPostgresSaver]) -> None:
    global _checkpointer
    _checkpointer = checkpointer


def get_checkpointer() -> Optional[AsyncPostgresSaver]:
    return _checkpointer


# 1. 初始化LLM
llm = ChatOpenAI(
    model=settings.openai_model,
    api_key=settings.openai_api_key,
    base_url=settings.openai_api_url,
    temperature=0.7,
    streaming=True
)


# 2. 构建 Expert Agent（只读）
def build_expert_agent(expert_id: str, checkpointer: Optional[AsyncPostgresSaver] = None):
    """构建指定领域的只读 Expert Agent"""

    info = EXPERTS.get(expert_id)
    if not info:
        raise ValueError(f"Unknown expert: {expert_id}")

    tools = get_tools_for_domains(info.tools, exclude=info.excluded_tools)
    cp = checkpointer or get_checkpointer()

    return create_agent(
        model=llm,
        tools=tools,
        system_prompt=info.system_prompt,
        checkpointer=cp
    )


# 3. 通用只读工具（主 Agent 直接使用，不通过 Expert）
def get_common_tools() -> list:
    """获取只读通用工具（监测点/报警查询/天气/RAG）。

    报警处理 handle_alarm 属于高危写操作，由 gated 工具单独提供。
    """
    return list(get_tools_for_domains(["monitor", "alarm", "weather", "rag"],
                                      exclude=("handle_alarm",)))


# 4. 高危写工具（带人工确认）
def get_gated_write_tools() -> list:
    """获取需要人工二次确认的写操作工具"""
    return [control_device, start_irrigation, stop_irrigation, handle_alarm]


# 5. 异步 Expert 调用工具（替代旧的 asyncio.run 同步实现）
def make_expert_tool(expert_id: str, info):
    """工厂函数：为单个专家生成独立命名的异步工具，避免闭包覆盖。"""

    tool_name = f"consult_{expert_id}_expert"

    @tool(
        name=tool_name,
        description=f"{info.description}。当你需要{info.name}处理「{expert_id}」领域的只读查询时调用此工具。",
    )
    async def consult_expert(query: str, config: RunnableConfig) -> str:
        """调用对应的只读 Expert Agent 处理请求（全链路异步，无嵌套事件循环）"""
        from app.agent.experts.executor import run_expert

        parent_thread = (
            config.get("configurable", {}).get("thread_id", "default")
            if config else "default"
        )
        return await run_expert(expert_id, query, parent_thread)

    consult_expert.name = tool_name
    return consult_expert


def get_expert_tools() -> list:
    """获取所有 Expert 异步工具（供主 Agent 使用）"""
    return [make_expert_tool(expert_id, info) for expert_id, info in EXPERTS.items()]


def build_main_agent(checkpointer: Optional[AsyncPostgresSaver] = None,
                     model_override=None):
    """构建主Agent（协调器）

    Args:
        checkpointer: 会话持久化
        model_override: 模型分级路由传入的小模型实例（默认用主模型 llm）
    """
    cp = checkpointer or get_checkpointer()

    # 主Agent的工具 = 只读通用工具 + 高危写工具(人工确认) + 异步Expert工具
    tools = get_common_tools()
    tools.extend(get_gated_write_tools())
    tools.extend(get_expert_tools())

    return create_agent(
        model=model_override or llm,
        tools=tools,
        system_prompt=MAIN_AGENT_PROMPT,
        checkpointer=cp
    )


# 主Agent系统提示词
MAIN_AGENT_PROMPT = """你是一个智慧农业系统的AI助手，可以帮助农民管理农场。

【你的职责】
理解用户需求：只读查询分派给合适的专家或直接使用工具；高危写操作由你在用户确认后亲自执行。

【可用专家（均为只读查询）】
1. 设备管理专家 - 查询设备列表与实时状态
2. 灌溉管理专家 - 查询灌溉记录与统计
3. 环境监测专家 - 查询和分析环境数据
4. 智能灌溉专家 - 湿度预测、作物管理、算法分析

【你可直接使用的只读功能】
- 监测点管理：查看监测点列表和详情
- 报警查询：查看报警列表和未处理数量
- 天气查询：获取天气预报
- 知识问答：根据RAG知识库回答农业问题

【高危写操作（必须人工确认）】
- control_device：设备开/关
- start_irrigation / stop_irrigation：开始/停止灌溉
- handle_alarm：处理（确认）报警
调用这些工具后系统会暂停并弹出确认卡片。若用户拒绝，必须如实告知"操作已取消"，不得声称执行成功。

【工作流程】
1. 理解用户意图
2. 查询类任务选择合适的专家或只读工具
3. 写操作先向用户说明将要执行的内容，再调用对应工具等待确认
4. 用简洁友好的中文向用户汇总结果

【回复要求】
- 用通俗易懂的语言（农民也能看懂）
- 给出实用建议
- 不要过度使用专业术语
- 所有写操作的成功与否以工具返回结果为准，禁止编造执行结果
- 知识库工具返回"知识库中未查询到相关内容"时，必须如实告知用户
  知识库中暂无该内容，禁止编造答案或虚构引用来源"""


async def run_expert_message(expert_id: str, message: str, thread_id: str = "default"):
    """运行Expert处理消息（兼容旧接口）"""
    from app.agent.experts.executor import run_expert
    return await run_expert(expert_id, message, thread_id)


async def run_main_agent(messages: list, thread_id: str = "default", checkpointer: Optional[AsyncPostgresSaver] = None):
    """运行主Agent（带记忆支持）"""
    agent = build_main_agent(checkpointer)
    config = {"configurable": {"thread_id": thread_id}}
    return await agent.ainvoke({"messages": messages}, config)
