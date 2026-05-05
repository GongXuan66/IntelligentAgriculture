import sys
from pathlib import Path

# 确保模块路径正确
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.config import settings

print("=== 配置加载成功 ===")
print(f"OpenAI Model: {settings.openai_model}")
print(f"OpenAI API URL: {settings.openai_api_url}")
print(f"RAG Embedding Model: {settings.rag_embedding_model}")
#print(f"RAG API URL: {settings.rag_embedding_api_base}")
print(f"Java Backend URL: {settings.java_backend_url}")
print()

# 测试 LLM 初始化
print("=== 测试 LLM 初始化 ===")
try:
    from app.agent.assistant import llm
    print(f"LLM 类型: {type(llm)}")
    print("LLM 初始化成功")
except Exception as e:
    print(f"LLM 初始化失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

# 测试 Agent Builder
print("\n=== 测试 Agent 构建 ===")
try:
    from app.agent.assistant import build_agent
    agent = build_agent(("device", "environment", "irrigation", "alarm"))
    print(f"Agent 类型: {type(agent)}")
    print("Agent 构建成功")
except Exception as e:
    print(f"Agent 构建失败: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)

from langchain.agents import create_agent

from langgraph.checkpoint.postgres import PostgresSaver  # [!code highlight]


DB_URI = "postgresql://postgres:postgres@localhost:5432/ia_ai?sslmode=disable"
with PostgresSaver.from_conn_string(DB_URI) as checkpointer:
    checkpointer.setup() # auto create tables in PostgresSql
    agent = create_agent(
        model=llm,
        checkpointer=checkpointer,  # [!code highlight]
    )


print("\n=== 所有测试完成 ===")


