import asyncio
from typing import Optional
from langchain_openai import ChatOpenAI
from app.config import settings
from app.agent.tool_registry import get_tools_for_domains
from app.agent.experts.registry import EXPERTS
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver
from langchain.agents import create_agent
from langchain_core.tools import tool


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


# 2. 构建 Expert Agent
def build_expert_agent(expert_id: str, checkpointer: Optional[AsyncPostgresSaver] = None):
    """构建指定领域的Expert Agent"""

    info = EXPERTS.get(expert_id)
    if not info:
        raise ValueError(f"Unknown expert: {expert_id}")

    tools = get_tools_for_domains(info.tools)
    cp = checkpointer or get_checkpointer()

    return create_agent(
        model=llm,
        tools=tools,
        system_prompt=info.system_prompt,
        checkpointer=cp
    )


# 3. 通用工具（不通过Expert）
def get_common_tools() -> list:
    """获取通用工具（Farm/Monitor/Alarm/Weather/RAG等）"""
    return list(get_tools_for_domains(["monitor", "alarm", "weather", "rag"]))


def build_main_agent(checkpointer: Optional[AsyncPostgresSaver] = None):
    """构建主Agent（协调器）"""
    cp = checkpointer or get_checkpointer()

    # 主Agent的工具 = Expert调用 + 通用工具
    tools = get_common_tools()
    tools.extend(get_all_expert_tools())

    system_prompt = MAIN_AGENT_PROMPT

    return create_agent(
        model=llm,
        tools=tools,
        system_prompt=system_prompt,
        checkpointer=cp
    )


def get_all_expert_tools() -> list:
    """获取所有Expert工具（同步版本）"""
    tools = []
    for expert_id, info in EXPERTS.items():
        @tool(description=f"{info.description}。当你需要{expert_id}相关帮助时调用此工具。")
        def call_expert(query: str, expert_id: str = expert_id) -> str:
            """调用对应的Expert Agent处理请求"""
            import asyncio
            return asyncio.run(run_expert_unsafe_sync(expert_id, query))

        tools.append(call_expert)

    return tools


def run_expert_unsafe_sync(expert_id: str, query: str) -> str:
    """同步运行Expert"""
    from app.agent.experts.executor import run_expert
    return asyncio.run(run_expert(expert_id, query))


# 主Agent系统提示词
MAIN_AGENT_PROMPT = """你是一个智慧农业系统的AI助手，可以帮助农民管理农场。

【你的职责】
理解用户需求，调用合适的专家来处理请求，并将结果以友好的方式呈现给用户。

【可用专家】
1. 设备管理专家 - 负责设备查询、开关控制
2. 灌溉管理专家 - 负责灌溉控制、查看灌溉记录
3. 环境监测专家 - 负责环境数据查询和分析
4. 智能灌溉专家 - 负责智能预测、作物管理、算法分析

【通用功能】
- 监控点管理：查看监测点列表和详情
- 报警管理：查看和处理报警信息
- 天气查询：获取天气预报
- 农场管理：查看农场信息
- 知识问答：根据RAG知识库回答农业问题

【工作流程】
1. 理解用户意图
2. 选择合适的Expert或直接使用工具
3. 调用后返回结果
4. 用简洁友好的中文回复用户

【回复要求】
- 用通俗易懂的语言（农民也能看懂）
- 给出实用建议
- 不要过度使用专业术语"""


async def run_expert_message(expert_id: str, message: str, thread_id: str = "default"):
    """运行Expert处理消息（兼容旧接口）"""
    from app.agent.experts.executor import run_expert
    return await run_expert(expert_id, message, thread_id)


async def run_main_agent(messages: list, thread_id: str = "default", checkpointer: Optional[AsyncPostgresSaver] = None):
    """运行主Agent（带记忆支持）"""
    agent = build_main_agent(checkpointer)
    config = {"configurable": {"thread_id": thread_id}}
    return await agent.ainvoke({"messages": messages}, config)