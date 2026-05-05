from langchain_core.messages import HumanMessage, AIMessage
from app.agent.assistant import get_checkpointer, llm


async def run_expert(expert_id: str, query: str, thread_id: str = "default") -> str:
    """
    运行指定的Expert Agent处理查询

    Args:
        expert_id: 专家ID (device/irrigation/environment/smart_irrigation)
        query: 用户查询
        thread_id: 会话ID

    Returns:
        Expert的处理结果
    """
    from app.agent.experts.registry import EXPERTS
    from app.agent.assistant import build_expert_agent

    # 验证expert_id
    info = EXPERTS.get(expert_id)
    if not info:
        return f"错误：未知的专家类型 '{expert_id}'"

    # 构建Expert Agent
    checkpointer = get_checkpointer()
    agent = build_expert_agent(expert_id, checkpointer)

    # 配置会话
    config = {"configurable": {"thread_id": f"expert_{expert_id}_{thread_id}"}}

    # 构建消息
    messages = [HumanMessage(content=query)]

    try:
        # 执行
        result = await agent.ainvoke({"messages": messages}, config)
        result_messages = result.get("messages", []) if isinstance(result, dict) else []

        # 提取AI回复
        answer = ""
        for msg in reversed(result_messages):
            if isinstance(msg, AIMessage):
                content = msg.content
                if isinstance(content, str):
                    answer = content
                elif isinstance(content, list):
                    answer = "".join(
                        item.get("text", "") if isinstance(item, dict) else str(item)
                        for item in content
                    )
                else:
                    answer = str(content)
                break

        return answer or "Expert 处理完成，但没有返回结果"

    except Exception as e:
        return f"处理请求时出错: {str(e)}"


async def run_expert_with_context(
    expert_id: str,
    query: str,
    context: str,
    thread_id: str = "default"
) -> str:
    """
    带上下文的Expert调用

    Args:
        expert_id: 专家ID
        query: 用户查询
        context: 附加上下文信息
        thread_id: 会话ID
    """
    from app.agent.experts.registry import EXPERTS
    from app.agent.assistant import build_expert_agent

    info = EXPERTS.get(expert_id)
    if not info:
        return f"错误：未知的专家类型 '{expert_id}'"

    # 在查询前附加上下文
    enhanced_query = f"""【上下文】
{context}

【用户问题】
{query}"""

    return await run_expert(expert_id, enhanced_query, thread_id)