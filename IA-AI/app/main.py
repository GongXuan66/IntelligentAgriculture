from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, AsyncGenerator
import json
from langchain_core.messages import AIMessage, HumanMessage

from app.agent.assistant import build_main_agent, set_checkpointer, get_checkpointer, DB_URI
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with AsyncPostgresSaver.from_conn_string(DB_URI) as checkpointer:
        await checkpointer.setup()
        set_checkpointer(checkpointer)
        yield
    set_checkpointer(None)


app = FastAPI(
    title="智慧农业AI服务",
    description="基于LangChain的智能农业对话系统",
    version="1.0.0",
    lifespan=lifespan
)


# CORS跨域支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============ 请求模型 ============
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = "default"


class ChatSyncRequest(BaseModel):
    message: str
    session_id: Optional[str] = "default"


class ClearSessionRequest(BaseModel):
    session_id: str


# ============ 工具函数 ============

def require_checkpointer():
    checkpointer = get_checkpointer()
    if not checkpointer:
        raise HTTPException(status_code=503, detail="Checkpointer not initialized")
    return checkpointer


async def read_checkpointer(checkpointer, config):
    if hasattr(checkpointer, "aget"):
        return await checkpointer.aget(config)
    return checkpointer.get(config)


# ============ 接口 ============

@app.get("/")
async def root():
    """健康检查"""
    return {"status": "ok", "message": "智慧农业AI服务运行中"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


# ============ Memory 管理接口 ============

@app.get("/api/memory/sessions")
async def list_sessions():
    """获取所有会话ID列表（需要外部存储支持）"""
    return {"message": "使用checkpointer持久化，需要外部存储支持列出所有会话"}


@app.get("/api/memory/session/{session_id}")
async def get_session_info(session_id: str):
    """获取指定会话的信息"""
    try:
        checkpointer = require_checkpointer()
        config = {"configurable": {"thread_id": session_id}}
        state = await read_checkpointer(checkpointer, config)
        if state is None:
            raise HTTPException(status_code=404, detail="Session not found")
        return {
            "session_id": session_id,
            "exists": True
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.post("/api/chat")
async def chat(request: ChatRequest):
    """
    流式对话接口 (SSE) - 使用主Agent（带Expert子Agent）
    """
    session_id = request.session_id or "default"

    async def generate() -> AsyncGenerator[str, None]:
        try:
            checkpointer = require_checkpointer()
            agent = build_main_agent(checkpointer)

            config = {"configurable": {"thread_id": session_id}}
            messages = [HumanMessage(content=request.message)]

            async for event in agent.astream_events(
                {"messages": messages},
                config,
                version="v1"
            ):
                if event["event"] == "on_chat_model_stream":
                    content = event["data"]["chunk"].content
                    if isinstance(content, list):
                        for item in content:
                            if item.get("type") == "text":
                                yield f"data: {json.dumps({'token': item['text']}, ensure_ascii=False)}\n\n"
                    elif isinstance(content, str):
                        yield f"data: {json.dumps({'token': content}, ensure_ascii=False)}\n\n"

            yield f"data: {json.dumps({'done': True})}\n\n"

        except Exception as exc:
            yield f"data: {json.dumps({'error': str(exc)})}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )


@app.post("/api/chat/sync")
async def chat_sync(request: ChatSyncRequest):
    """
    同步对话接口（非流式）- 使用主Agent（带Expert子Agent）
    """
    session_id = request.session_id or "default"

    try:
        checkpointer = require_checkpointer()
        agent = build_main_agent(checkpointer)

        config = {"configurable": {"thread_id": session_id}}
        messages = [HumanMessage(content=request.message)]

        result = await agent.ainvoke({"messages": messages}, config)
        result_messages = result.get("messages", []) if isinstance(result, dict) else []

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

        if not answer:
            raise RuntimeError("agent returned empty assistant message")

        return {"session_id": session_id, "answer": answer}
    except Exception as exc:
        import traceback
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.post("/api/chat/clear")
async def clear_session(request: ClearSessionRequest):
    """清除会话历史"""
    try:
        checkpointer = require_checkpointer()
        if hasattr(checkpointer, "adelete_thread"):
            await checkpointer.adelete_thread(request.session_id)
        elif hasattr(checkpointer, "delete_thread"):
            checkpointer.delete_thread(request.session_id)
        else:
            raise HTTPException(status_code=501, detail="Checkpointer does not support delete")
        return {"message": "会话已清除"}
    except HTTPException:
        raise
    except Exception as e:
        return {"message": f"清除会话失败: {str(e)}"}


@app.delete("/api/memory/session/{session_id}")
async def delete_session(session_id: str):
    """删除指定会话"""
    try:
        checkpointer = require_checkpointer()
        if hasattr(checkpointer, "adelete_thread"):
            await checkpointer.adelete_thread(session_id)
        elif hasattr(checkpointer, "delete_thread"):
            checkpointer.delete_thread(session_id)
        else:
            raise HTTPException(status_code=501, detail="Checkpointer does not support delete")
        return {"message": f"会话 {session_id} 已删除"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/memory/all")
async def delete_all_sessions():
    """删除所有会话 - MemorySaver不直接支持，需要外部存储"""
    return {
        "message": "MemorySaver不支持批量删除，请使用外部存储（PostgreSQL）来实现此功能"
    }


@app.post("/api/java/test")
async def java_test(request: ChatRequest):
    """测试是否和java后端联通"""
    from app.tools import device_tools
    list = await device_tools.get_all_devices()
    print(list)
    return {"message": "ok"}
