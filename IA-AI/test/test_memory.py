"""
Memory功能测试脚本 - 使用LangGraph Checkpointer

测试LangGraph官方推荐的短期记忆机制
"""
from pathlib import Path
from dotenv import load_dotenv

# 加载.env配置
env_path = Path(__file__).parent.parent / "app" / ".env"
load_dotenv(dotenv_path=str(env_path))

from langchain_core.messages import HumanMessage, AIMessage


def test_agent_with_checkpointer():
    """测试Agent + Checkpointer（官方推荐方式）"""
    print("=== 测试 LangGraph Agent + Checkpointer ===\n")

    try:
        from langchain.agents import create_agent
        from langgraph.checkpoint.memory import MemorySaver
        from langchain_openai import ChatOpenAI
        from langchain_core.tools import tool

        @tool
        def get_weather(city: str = "北京") -> str:
            """获取城市天气"""
            return f"{city}今天晴朗，25度"

        # 从环境变量加载配置
        import os
        api_key = os.environ.get("OPENAI_API_KEY", "")
        base_url = os.environ.get("OPENAI_API_URL", "https://api.openai.com/v1")
        model = os.environ.get("OPENAI_MODEL", "Qwen/Qwen3.5-35B-A3B")

        if not api_key:
            print("警告: 未设置OPENAI_API_KEY，跳过LLM测试")
            print("可设置环境变量后重试")
            return

        print(f"使用模型: {model}")
        print(f"API地址: {base_url}")

        llm = ChatOpenAI(
            model=model,
            api_key=api_key,
            base_url=base_url
        )

        # 创建带checkpointer的agent
        checkpointer = MemorySaver()
        agent = create_agent(llm, [get_weather], checkpointer=checkpointer)

        config = {"configurable": {"thread_id": "test_conversation"}}

        # 第1轮对话
        print("1. 第1轮对话: 询问北京天气")
        result1 = agent.invoke(
            {"messages": [HumanMessage(content="北京天气怎么样？")]},
            config
        )
        print(f"   用户: 北京天气怎么样？")
        print(f"   AI: {result1['messages'][-1].content}")

        # 第2轮对话 - checkpointer会自动记住历史
        print("\n2. 第2轮对话: 追问上海")
        result2 = agent.invoke(
            {"messages": [HumanMessage(content="那上海呢？")]},
            config
        )
        print(f"   用户: 那上海呢？")
        print(f"   AI: {result2['messages'][-1].content}")

        # 第3轮对话 - 验证历史可用
        print("\n3. 第3轮对话: 问我的名字（测试记忆）")
        result3 = agent.invoke(
            {"messages": [HumanMessage(content="我之前说过什么？")]},
            config
        )
        print(f"   用户: 我之前说过什么？")
        print(f"   AI: {result3['messages'][-1].content}")

        # 打印完整历史
        print(f"\n4. 对话历史（共{len(result3['messages'])}条消息）:")
        for i, msg in enumerate(result3['messages']):
            role = "用户" if isinstance(msg, HumanMessage) else "AI"
            content = msg.content if isinstance(msg.content, str) else str(msg.content)
            if len(content) > 50:
                content = content[:50] + "..."
            print(f"   [{i+1}] {role}: {content}")

        # 测试不同会话隔离
        print("\n5. 测试不同会话隔离")
        config2 = {"configurable": {"thread_id": "different_user"}}
        result4 = agent.invoke(
            {"messages": [HumanMessage(content="你好")]}
            , config2
        )
        print(f"   新会话用户: 你好")
        print(f"   新会话AI: {result4['messages'][-1].content}")

        print("\n=== 测试完成 ===")

    except Exception as e:
        import traceback
        print(f"错误: {type(e).__name__}: {e}")
        traceback.print_exc()


if __name__ == "__main__":
    test_agent_with_checkpointer()