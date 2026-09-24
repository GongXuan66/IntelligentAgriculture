from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import Optional, AsyncGenerator, Any
import json
import time
from langchain_core.messages import AIMessage, HumanMessage
from langgraph.types import Command
from langgraph.checkpoint.postgres.aio import AsyncPostgresSaver

from app.agent.assistant import build_main_agent, set_checkpointer, get_checkpointer, DB_URI, llm
from app.agent.experts.registry import EXPERTS
from app.agent.model_router import route_model
from app.guardrails import check_input
from app.guardrails.rate_limit import rate_limiter
from app.observability.token_stats import extract_usage, token_stats

# 工具结果在 SSE 中展示的最大字符数，超长截断
TOOL_RESULT_PREVIEW_LIMIT = 500


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


class ResumeRequest(BaseModel):
    session_id: str
    approved: bool


class WorkflowRunRequest(BaseModel):
    point_id: int = 1
    threshold: float = 40.0
    session_id: Optional[str] = None


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


def sse(payload: dict[str, Any]) -> str:
    """统一 SSE 事件帧：data: {json}\\n\\n"""
    return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"


def _truncate(text: str, limit: int = TOOL_RESULT_PREVIEW_LIMIT) -> str:
    if len(text) <= limit:
        return text
    return text[:limit] + f"\n...（结果过长，已截断，共 {len(text)} 字符）"


def _stringify_tool_result(result: Any) -> str:
    if isinstance(result, str):
        return result
    try:
        return json.dumps(result, ensure_ascii=False, default=str)
    except Exception:
        return str(result)


def _is_consult_expert(tool_name: str) -> Optional[str]:
    """consult_device_expert -> device，否则 None"""
    if tool_name and tool_name.startswith("consult_") and tool_name.endswith("_expert"):
        return tool_name[len("consult_"):-len("_expert")]
    return None


async def _stream_agent_events(agent, agent_input: Any, config: dict,
                               session_id: str = "default",
                               path: str = "/api/chat") -> AsyncGenerator[str, None]:
    """消费 LangGraph 执行过程，产出统一多事件 SSE 帧。

    事件类型：token / tool_start / tool_end / expert_handoff /
    rag_retrieve / approval_required / done / error
    同时在流结束时汇总记录 Token 用量与耗时。
    """
    started_at = time.monotonic()
    usages: list[dict] = []
    try:
        async for event in agent.astream_events(agent_input, config, version="v2"):
            kind = event.get("event")

            if kind == "on_chat_model_end":
                usage = extract_usage(event)
                if usage:
                    usages.append(usage)

            if kind == "on_chat_model_stream":
                chunk = event["data"].get("chunk")
                content = getattr(chunk, "content", None)
                if isinstance(content, list):
                    for item in content:
                        if isinstance(item, dict) and item.get("type") == "text" and item.get("text"):
                            text = item["text"]
                            yield sse({"event": "token", "token": text})
                elif isinstance(content, str) and content:
                    yield sse({"event": "token", "token": content})

            elif kind == "on_tool_start":
                tool_name = event.get("name", "")
                args = event.get("data", {}).get("input", {}) or {}

                expert_id = _is_consult_expert(tool_name)
                if expert_id:
                    info = EXPERTS.get(expert_id)
                    query = args.get("query", "") if isinstance(args, dict) else ""
                    yield sse({
                        "event": "expert_handoff",
                        "expert": expert_id,
                        "expert_name": info.name if info else expert_id,
                        "query": query,
                    })
                else:
                    yield sse({
                        "event": "tool_start",
                        "tool": tool_name,
                        "args": args if isinstance(args, dict) else {"input": str(args)},
                    })

            elif kind == "on_tool_end":
                tool_name = event.get("name", "")
                if _is_consult_expert(tool_name):
                    # 专家内部完成的子工具不再冒泡为独立轨迹，仅给出专家返回摘要
                    output = event.get("data", {}).get("output")
                    yield sse({
                        "event": "tool_end",
                        "tool": tool_name,
                        "result": _truncate(_stringify_tool_result(output)),
                    })
                    continue

                output = event.get("data", {}).get("output")
                result_text = _truncate(_stringify_tool_result(output))
                yield sse({"event": "tool_end", "tool": tool_name, "result": result_text})

                if tool_name == "search_knowledge_base":
                    yield sse({
                        "event": "rag_retrieve",
                        "tool": tool_name,
                        "snippet": result_text,
                    })

        # 执行结束后检查是否因高危写操作中断，等待人工确认
        state = await agent.aget_state(config)
        interrupt_info = _extract_interrupt(state)
        if interrupt_info:
            yield sse({"event": "approval_required", **interrupt_info})
            return  # 不发 done，前端据此保持待确认状态

        yield sse({"event": "done", "done": True})

    except Exception as exc:  # noqa: BLE001 - SSE 内无法再走 HTTP 异常
        import traceback
        traceback.print_exc()
        yield sse({"event": "error", "error": str(exc), "message": str(exc)})
    finally:
        # 汇总本次请求的 Token 用量与耗时（多次 LLM 调用累加）
        duration_ms = (time.monotonic() - started_at) * 1000
        if usages:
            token_stats.record(
                session_id=session_id,
                model=usages[-1]["model"],
                input_tokens=sum(u["input_tokens"] for u in usages),
                output_tokens=sum(u["output_tokens"] for u in usages),
                duration_ms=duration_ms,
                path=path,
            )


def _extract_interrupt(state: Any) -> Optional[dict]:
    """从 graph state.tasks[].interrupts[] 提取第一个审批请求载荷。"""
    tasks = getattr(state, "tasks", None) or []
    for task in tasks:
        interrupts = getattr(task, "interrupts", None) or []
        for itr in interrupts:
            value = getattr(itr, "value", None)
            if isinstance(value, dict) and value.get("type") == "approval_request":
                return {
                    "tool": value.get("tool"),
                    "args": value.get("args", {}),
                    "summary": value.get("summary", ""),
                }
    return None


# ============ 接口 ============

@app.get("/")
async def root():
    """健康检查"""
    return {"status": "ok", "message": "智慧农业AI服务运行中"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.get("/api/stats")
async def get_stats():
    """Token 用量与耗时统计（模型分级路由效果、成本分析数据源）"""
    return token_stats.snapshot()


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
async def chat(request: ChatRequest, raw: Request):
    """
    流式对话接口 (SSE) - 使用主Agent（带只读Expert子Agent + 高危操作人工确认）

    SSE 事件：token / tool_start / tool_end / expert_handoff /
    rag_retrieve / approval_required / done / error
    """
    session_id = request.session_id or "default"

    # 输入护轨：注入特征 / 越权指令规则拦截
    verdict = check_input(request.message)
    if not verdict.allowed:
        raise HTTPException(status_code=400, detail=verdict.reason)

    # 三级令牌桶限流：IP / 会话 / 全局
    client_ip = raw.client.host if raw.client else "unknown"
    rl = rate_limiter.check(client_ip, session_id)
    if not rl.allowed:
        raise HTTPException(status_code=429, detail=rl.reason)

    checkpointer = require_checkpointer()
    # 模型分级路由：简单意图走小模型（未配置则回退主模型）
    agent = build_main_agent(checkpointer, model_override=route_model(request.message, llm))
    config = {"configurable": {"thread_id": session_id}}
    agent_input = {"messages": [HumanMessage(content=request.message)]}

    return StreamingResponse(
        _stream_agent_events(agent, agent_input, config,
                             session_id=session_id, path="/api/chat"),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )


@app.post("/api/chat/resume")
async def chat_resume(request: ResumeRequest):
    """用户对高危写操作做出确认/拒绝后，恢复被 interrupt 暂停的执行流（SSE）。"""
    checkpointer = require_checkpointer()
    agent = build_main_agent(checkpointer)
    config = {"configurable": {"thread_id": request.session_id}}
    agent_input = Command(resume={"approved": request.approved})

    return StreamingResponse(
        _stream_agent_events(agent, agent_input, config,
                             session_id=request.session_id, path="/api/chat/resume"),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        }
    )


@app.post("/api/chat/sync")
async def chat_sync(request: ChatRequest):
    """
    同步对话接口（非流式）- 使用主Agent（带Expert子Agent）。

    注意：若命中高危写操作，图会停在 interrupt，本接口不会自动确认，
    需要改用 /api/chat + /api/chat/resume 的流式流程。
    """
    session_id = request.session_id or "default"

    # 输入护轨：注入特征 / 越权指令规则拦截
    verdict = check_input(request.message)
    if not verdict.allowed:
        raise HTTPException(status_code=400, detail=verdict.reason)

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
            state = await agent.aget_state(config)
            if _extract_interrupt(state):
                raise RuntimeError("该请求触发高危操作，等待人工确认，请使用流式接口完成审批")
            raise RuntimeError("agent returned empty assistant message")

        return {"session_id": session_id, "answer": answer}
    except HTTPException:
        raise
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


# ============ 智能灌溉决策工作流（LangGraph 编排） ============

async def _stream_workflow_events(workflow, workflow_input, config, thread_id):
    """以节点为单位流式输出工作流执行过程（updates 模式）。"""
    try:
        async for chunk in workflow.astream(workflow_input, config, stream_mode="updates"):
            for node_name, update in chunk.items():
                if node_name == "__interrupt__":
                    continue
                steps = (update or {}).get("steps", [])
                yield sse({
                    "event": "workflow_node",
                    "node": node_name,
                    "step": steps[-1] if steps else "",
                    "steps": steps,
                })

        state = await workflow.aget_state(config)
        interrupt_info = _extract_interrupt(state)
        if interrupt_info:
            yield sse({"event": "approval_required", **interrupt_info})
            return

        # 收尾：输出最终决策摘要
        final = (state.values or {}) if hasattr(state, "values") else {}
        yield sse({
            "event": "workflow_done",
            "decision": final.get("decision"),
            "execute_result": (final.get("execute_result") or {}).get("skipped", None) is not True,
            "learn_result": final.get("learn_result"),
        })
        yield sse({"event": "done", "done": True})

    except Exception as exc:  # noqa: BLE001
        import traceback
        traceback.print_exc()
        yield sse({"event": "error", "error": str(exc), "message": str(exc)})


@app.post("/api/irrigation/workflow/run")
async def run_irrigation_workflow(request: WorkflowRunRequest):
    """
    运行智能灌溉决策工作流（SSE）。

    节点链：湿度预测 -> 风险系数 -> 条件决策 -> [人审 -> 执行 -> 学习回写]。
    决策为不灌溉时直接结束；需要灌溉时在 review 节点 interrupt，
    前端收到 approval_required 后调 /api/irrigation/workflow/resume。
    """
    from app.workflows.irrigation_graph import build_irrigation_workflow

    checkpointer = require_checkpointer()
    workflow = build_irrigation_workflow(checkpointer)
    thread_id = request.session_id or f"irr_wf_{request.point_id}"
    config = {"configurable": {"thread_id": thread_id}}
    workflow_input = {"point_id": request.point_id, "threshold": request.threshold}

    return StreamingResponse(
        _stream_workflow_events(workflow, workflow_input, config, thread_id),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive",
                 "X-Accel-Buffering": "no"},
    )


@app.post("/api/irrigation/workflow/resume")
async def resume_irrigation_workflow(request: ResumeRequest):
    """人审确认/拒绝后恢复工作流（SSE）。"""
    from app.workflows.irrigation_graph import build_irrigation_workflow

    checkpointer = require_checkpointer()
    workflow = build_irrigation_workflow(checkpointer)
    config = {"configurable": {"thread_id": request.session_id}}
    workflow_input = Command(resume={"approved": request.approved})

    return StreamingResponse(
        _stream_workflow_events(workflow, workflow_input, config, request.session_id),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "Connection": "keep-alive",
                 "X-Accel-Buffering": "no"},
    )


@app.post("/api/java/test")
async def java_test(request: ChatRequest):
    """测试是否和java后端联通"""
    from app.tools import device_tools
    devices = await device_tools.get_all_devices.ainvoke({})
    print(devices)
    return {"message": "ok"}
