# LangChain Python AI 服务实现教程

以学习为目的，一步步实现智慧农业的Python AI服务。

---

## 整体架构

```
┌─────────────────────────────────────────────────────────────────┐
│                        Python AI 服务                           │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────────────┐   │
│  │   FastAPI   │◄──┤   LangChain │◄──┤  LangGraph Agent    │   │
│  │  (HTTP API) │   │   (LLM调用)  │   │  (Tool Calling)    │   │
│  └─────────────┘   └─────────────┘   └─────────────────────┘   │
│         │                                       │               │
│         ▼                                       ▼               │
│  ┌─────────────┐                       ┌─────────────────────┐  │
│  │  会话管理    │                       │   Custom Tools      │  │
│  │ (内存/Redis)│                       │ - DeviceTools       │  │
│  └─────────────┘                       │ - IrrigationTools   │  │
│                                         │ - EnvironmentTools  │  │
│                                         │ - AlarmTools        │  │
│                                         │ - MonitorPointTools │  │
│                                         └─────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │
                            ▼ HTTP/REST
┌─────────────────────────────────────────────────────────────────┐
│                      Java后端 (IA-server)                        │
│         设备管理 │ 灌溉管理 │ 传感器数据 │ 报警管理              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 第一步：环境准备

首先创建Python项目的基础环境。

### 1.1 创建项目目录和虚拟环境

```bash
# 在 IA-AI 目录下
cd IA-AI

# 创建虚拟环境（推荐）
python -m venv venv

# 激活虚拟环境
# Windows:
venv\Scripts\activate
# Mac/Linux:
source venv/bin/activate
```

### 1.2 安装依赖

创建 `requirements.txt`：

```txt
langchain>=0.3.0
langchain-openai>=0.2.0
langgraph>=0.2.0
fastapi>=0.115.0
uvicorn[standard]>=0.30.0
httpx>=0.27.0
pydantic>=2.9.0
pydantic-settings>=2.5.0
python-dotenv>=1.0.0
```

安装：

```bash
pip install -r requirements.txt
```

### 1.3 创建基础目录结构

```bash
mkdir -p app/api app/services app/agent app/tools app/memory
touch app/__init__.py app/api/__init__.py app/services/__init__.py
touch app/agent/__init__.py app/tools/__init__.py app/memory/__init__.py
```

**思考题**：为什么要用虚拟环境？直接全局安装不行吗？

> 答案：虚拟环境可以隔离不同项目的依赖，避免版本冲突。每个项目应该有自己独立的依赖环境。

---

## 第二步：配置管理

创建 `app/config.py`，学会用Pydantic管理配置。

### 你的任务

在 `app/config.py` 中实现：

```python
from pydantic_settings import BaseSettings
from typing import Optional
import os
from dotenv import load_dotenv

# 加载.env文件
load_dotenv()

class Settings(BaseSettings):
    """应用配置"""

    # ===== LLM配置 =====
    openai_api_key: str = ""
    openai_base_url: str = "https://api.openai.com/v1"
    openai_model: str = "gpt-4o-mini"

    # ===== Java后端配置 =====
    java_backend_url: str = "http://localhost:8080"

    # ===== 服务配置 =====
    host: str = "0.0.0.0"
    port: int = 8000

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"

settings = Settings()
```

创建 `.env` 文件：

```bash
# LLM
OPENAI_API_KEY=your-api-key-here
OPENAI_BASE_URL=https://api.openai.com/v1
OPENAI_MODEL=gpt-4o-mini

# Java后端
JAVA_BACKEND_URL=http://localhost:8080

# 服务
HOST=0.0.0.0
PORT=8000
```

**练习**：尝试 `python -c "from app.config import settings; print(settings.openai_model)"` 检查配置是否生效。

---

## 第三步：HTTP客户端

实现调用Java后端的HTTP客户端，这是连接两个服务的桥梁。

### 你的任务

创建 `app/services/http_client.py`，将Java的Tool翻译成HTTP调用：

```python
import httpx
from typing import Any, Dict, Optional
from app.config import settings


class JavaBackendClient:
    """HTTP调用Java后端API"""

    def __init__(self):
        self.base_url = settings.java_backend_url
        self.client = httpx.AsyncClient(timeout=30.0)

    async def close(self):
        await self.client.aclose()

    # ============ 设备管理 ============
    async def get_all_devices(self) -> list[dict]:
        """获取所有设备"""
        # TODO: 实现 GET 请求到 /api/device/list
        pass

    async def get_devices_by_point(self, point_id: int) -> list[dict]:
        """根据检测点ID获取设备"""
        # TODO: 实现
        pass

    async def control_device(self, device_code: str, command: str) -> dict:
        """控制设备开关"""
        # TODO: 实现 POST 请求，command是 'on' 或 'off'
        pass

    # ============ 环境监测 ============
    async def get_current_environment(self, point_id: int) -> dict:
        """获取当前环境数据"""
        # TODO: 实现
        pass

    async def get_history_environment(self, point_id: int, limit: int = 10) -> list[dict]:
        """获取历史环境数据"""
        # TODO: 实现
        pass

    # ============ 灌溉管理 ============
    async def start_irrigation(self, point_id: int, duration: int = 60, mode: int = 1) -> dict:
        """开始灌溉"""
        # TODO: 实现
        pass

    async def stop_irrigation(self, log_id: int) -> dict:
        """停止灌溉"""
        # TODO: 实现
        pass

    # ============ 报警管理 ============
    async def get_unprocessed_alarms(self) -> list[dict]:
        """获取未处理报警"""
        # TODO: 实现
        pass

    async def handle_alarm(self, alarm_id: int, remark: str = "") -> dict:
        """处理报警"""
        # TODO: 实现
        pass

    # ============ 监控点 ============
    async def get_all_monitor_points(self) -> list[dict]:
        """获取所有监控点"""
        # TODO: 实现
        pass

    # ============ 私有方法 ============
    async def _get(self, path: str) -> Any:
        """GET请求辅助方法"""
        # TODO: 实现通用的GET请求
        # 1. 拼接URL
        # 2. 发送请求
        # 3. 解析响应，提取data字段
        pass

    async def _post(self, path: str, payload: dict) -> Any:
        """POST请求辅助方法"""
        # TODO: 实现通用的POST请求
        pass


# 全局实例
java_client = JavaBackendClient()
```

**关键点**：
- 使用 `httpx.AsyncClient` 发送HTTP请求
- 注意resp.json()的结构，通常 `{ "code": 200, "data": {...} }`

**思考题**：为什么要用异步（async/await）？同步不行吗？

> 答案：异步可以提高并发性能。在AI服务中，可能同时处理多个用户的请求，异步IO可以让服务器在等待HTTP响应时处理其他请求，提高吞吐量。

---

## 第四步：定义LangChain Tools

这里开始真正用到LangChain。将HTTP客户端封装成AI可以调用的Tools。

### 你的任务

创建 `app/tools/device_tools.py`：

```python
from langchain_core.tools import tool
from app.services.http_client import java_client


@tool(description="""
获取系统中所有设备列表，包括设备的ID、名称、类型和当前状态。
返回设备的基本信息。
""")
async def get_all_devices() -> str:
    """
    获取所有设备列表

    Returns:
        设备列表的JSON字符串
    """
    # TODO: 调用HTTP客户端并返回结果
    # 提示：转换为字符串返回，便于LLM理解
    pass


@tool(description="""
根据检测点ID获取该检测点下的所有设备。

参数:
    point_id: 检测点ID
""")
async def get_devices_by_point_id(point_id: int) -> str:
    """获取指定检测点的设备"""
    # TODO: 调用HTTP客户端
    pass


@tool(description="""
根据设备编码获取设备的详细信息。

参数:
    device_code: 设备编码
""")
async def get_device_by_device_code(device_code: str) -> str:
    """获取设备详情"""
    pass


@tool(description="""
控制设备开关。

参数:
    device_code: 设备编码
    command: 命令，"on"开启设备，"off"关闭设备
""")
async def control_device(device_code: str, command: str) -> str:
    """控制设备开关"""
    # TODO: 验证command只能是 'on' 或 'off'
    # 调用HTTP客户端
    pass
```

### 4.1 类似地创建其他Tools

- `app/tools/environment_tools.py` - 环境监测
- `app/tools/irrigation_tools.py` - 灌溉控制
- `app/tools/alarm_tools.py` - 报警管理
- `app/tools/monitor_tools.py` - 监控点

### 4.2 统一导出

创建 `app/tools/__init__.py`：

```python
from app.tools.device_tools import (
    get_all_devices,
    get_devices_by_point_id,
    get_device_by_device_code,
    control_device
)
# 导入其他tools...

__all__ = [
    "get_all_devices",
    "get_devices_by_point_id",
    "get_device_by_device_code",
    "control_device",
    # ... 其他
]
```

**关键点**：
- `@tool` 装饰器是LangChain的核心，它会自动生成函数签名给LLM
- `description` 参数非常重要，LLM靠它判断什么时候调用这个Tool

**练习**：为 `get_current_environment(point_id: int)` 编写Tool，参数描述要清晰。

---

## 第五步：创建LangChain Agent

这是核心 - 让LLM能够调用Tools。

### 你的任务

创建 `app/agent/prompt.py`，定义System Prompt：

```python
SYSTEM_PROMPT = """你是一个智慧农业系统的专业助手。

【系统操作能力】你拥有以下工具可以使用：

设备管理：
- get_all_devices: 获取所有设备列表
- get_devices_by_point_id: 获取指定检测点的设备
- control_device: 控制设备开关（需要device_code和command）

环境监测：
- get_current_environment: 获取当前环境数据
- get_history_environment: 获取历史环境数据
- get_environment_analysis: 分析环境状况

灌溉控制：
- start_irrigation: 开始灌溉
- stop_irrigation: 停止灌溉
- check_irrigation_need: 检查是否需要灌溉

报警管理：
- get_unprocessed_alarms: 获取未处理报警
- handle_alarm: 处理报警

监控点管理：
- get_all_monitor_points: 获取所有监控点

当用户询问设备状态、启动灌溉、查询环境数据时，你需要：
1. 先调用相关Tool获取数据
2. 用自然语言向用户汇报结果

请用中文简洁专业地回答问题。"""
```

### 5.1 创建Agent

创建 `app/agent/assistant.py`：

```python
from langchain_openai import ChatOpenAI
from langgraph.prebuilt import create_react_agent
from langchain_core.messages import HumanMessage
from app.config import settings
from app.agent.prompt import SYSTEM_PROMPT
from app.tools import (
    get_all_devices, get_devices_by_point_id,
    control_device, get_current_environment,
    start_irrigation, get_unprocessed_alarms,
    get_all_monitor_points
    # 导入所有tools
)

# 1. 初始化LLM
llm = ChatOpenAI(
    model=settings.openai_model,
    api_key=settings.openai_api_key,
    base_url=settings.openai_base_url,
    temperature=0.7,
    streaming=True  # 支持流式输出
)

# 2. 收集所有Tools
tools = [
    get_all_devices,
    get_devices_by_point_id,
    control_device,
    get_current_environment,
    start_irrigation,
    get_unprocessed_alarms,
    get_all_monitor_points,
    # ... 其他tools
]

# 3. 创建ReAct Agent
# ReAct = Reason + Act，让LLM先思考再行动
agent = create_react_agent(llm, tools)

# 4. 对话函数
async def chat(message: str, history: list = None):
    """
    执行对话

    Args:
        message: 用户消息
        history: 对话历史（可选）
    """
    # TODO: 构建消息列表
    # 如果有history，添加到消息中
    # 添加当前用户消息

    # TODO: 调用agent
    # result = await agent.ainvoke({"messages": messages})

    # TODO: 返回最后一条assistant消息
    pass
```

**关键点**：
- `create_react_agent` 是LangGraph提供的预建Agent，自动处理Tool Calling循环
- `streaming=True` 支持流式输出，体验更好

**思考题**：ReAct是什么？为什么让Agent先"思考"再"行动"？

> **ReAct (Reason + Act)** 是一种让LLM先推理决定要做什么，然后再执行的模式。
>
> 流程：观察 → 思考 → 行动 → 观察 → 思考 → ...
>
> 这样做的好处：LLM不会盲目行动，而是会先判断需要什么Tool，提取什么参数，提高准确率。

---

## 第六步：会话管理（Memory）

让AI记住对话历史，实现多轮对话。

### 你的任务

创建 `app/memory/session.py`：

```python
from typing import Dict, List
from collections import defaultdict
from langchain_core.messages import HumanMessage, AIMessage


class SessionManager:
    """会话记忆管理器"""

    def __init__(self):
        # TODO: 用字典存储会话历史
        # 格式: {session_id: [messages]}
        self.sessions: Dict[str, List] = defaultdict(list)

    def get_history(self, session_id: str) -> List:
        """获取会话历史"""
        # TODO: 返回历史消息列表
        pass

    def add_message(self, session_id: str, role: str, content: str):
        """
        添加消息到历史

        Args:
            session_id: 会话ID
            role: "user" 或 "assistant"
            content: 消息内容
        """
        # TODO: 根据role创建对应的Message对象
        # HumanMessage 或 AIMessage
        # 添加到sessions中
        pass

    def clear(self, session_id: str):
        """清除会话"""
        # TODO: 清空指定会话的历史
        pass

    def clear_all(self):
        """清除所有会话"""
        pass
```

**扩展挑战**：
- 如果想用Redis存储会话呢？修改 `__init__` 连接Redis
- 想限制历史消息长度（比如最多保留10轮）怎么做？

---

## 第七步：FastAPI服务

把一切封装成HTTP接口。

### 你的任务

创建 `app/main.py`：

```python
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import json

from app.agent.assistant import agent, SYSTEM_PROMPT
from app.memory.session import SessionManager

app = FastAPI(
    title="智慧农业AI服务",
    description="基于LangChain的智能农业对话系统",
    version="1.0.0"
)

# CORS跨域支持
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 会话管理器
session_manager = SessionManager()

# ============ 请求模型 ============
class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None


class ChatSyncRequest(BaseModel):
    message: str
    session_id: Optional[str] = None


class ClearSessionRequest(BaseModel):
    session_id: str


# ============ 接口 ============

@app.get("/")
async def root():
    """健康检查"""
    return {"status": "ok", "message": "智慧农业AI服务运行中"}


@app.get("/health")
async def health():
    return {"status": "healthy"}


@app.post("/api/chat")
async def chat(request: ChatRequest):
    """
    流式对话接口
    """
    session_id = request.session_id or "default"
    # TODO:
    # 1. 获取历史消息
    # 2. 构建消息列表
    # 3. 流式调用agent
    # 4. 返回Server-Sent Events (SSE)
    pass


@app.post("/api/chat/sync")
async def chat_sync(request: ChatSyncRequest):
    """
    同步对话接口（非流式）
    """
    session_id = request.session_id or "default"

    # TODO:
    # 1. 获取历史
    # 2. 调用agent.ainvoke
    # 3. 保存到历史
    # 4. 返回结果
    pass


@app.post("/api/chat/clear")
async def clear_session(request: ClearSessionRequest):
    """清除会话历史"""
    session_manager.clear(request.session_id)
    return {"message": "会话已清除"}
```

**关键点**：
- `/api/chat` 返回流式响应，使用 `StreamingResponse`
- SSE格式：`data: {json}\n\n`

---

## 第八步：运行测试

### 8.1 启动服务

```bash
cd IA-AI
uvicorn app.main:app --reload --port 8000
```

### 8.2 测试接口

用curl或Postman测试：

```bash
# 健康检查
curl http://localhost:8000/health

# 同步对话
curl -X POST http://localhost:8000/api/chat/sync \
  -H "Content-Type: application/json" \
  -d '{"message": "列出所有设备"}'

# 流式对话
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "检测点1当前温度多少？"}'
```

### 8.3 观察Agent的Tool Calling

发送 "帮我开启检测点1的设备"，观察：
1. Agent是否正确识别需要调用Tool
2. 调用了哪个Tool
3. 返回结果后如何回复

---

## 学习路线总结

```
第1步: 环境 → 会了pip和虚拟环境
    ↓
第2步: 配置 → 会了pydantic-settings
    ↓
第3步: HTTP客户端 → 会了httpx异步请求
    ↓
第4步: Tools → 会了@tool装饰器
    ↓
第5步: Agent → 会了LangChain Agent + ReAct
    ↓
第6步: Memory → 会了会话状态管理
    ↓
第7步: FastAPI → 会了RESTful接口
    ↓
第8步: 测试 → 端到端验证
```

---

## Java API 对应关系

| 功能 | Python Tool | Java Controller API |
|------|-------------|---------------------|
| 获取所有设备 | `get_all_devices` | `GET /api/device/list` |
| 根据检测点获取设备 | `get_devices_by_point_id` | `GET /api/device/point/{pointId}` |
| 控制设备 | `control_device` | `POST /api/device/control` |
| 获取当前环境 | `get_current_environment` | `GET /api/sensor/current/{pointId}` |
| 获取历史环境 | `get_history_environment` | `GET /api/sensor/history/{pointId}` |
| 开始灌溉 | `start_irrigation` | `POST /api/irrigation/start` |
| 停止灌溉 | `stop_irrigation` | `POST /api/irrigation/{logId}/stop` |
| 检查灌溉需求 | `check_irrigation_need` | `GET /api/irrigation/check/{pointId}` |
| 获取未处理报警 | `get_unprocessed_alarms` | `GET /api/alarm/unprocessed` |
| 处理报警 | `handle_alarm` | `POST /api/alarm/{id}/handle` |
| 获取监控点 | `get_all_monitor_points` | `GET /api/monitor-point/list` |

---

## 推荐学习资源

- [LangChain官方文档](https://python.langchain.com/)
- [LangGraph文档](https://langchain-ai.github.io/langgraph/)
- [FastAPI官方文档](https://fastapi.tiangolo.com/)
- [Pydantic文档](https://docs.pydantic.dev/)