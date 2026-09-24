# 智慧农业 Web 前端

React 18 + TypeScript + Vite + Ant Design + Zustand。
与 IA-server（Java 业务后端）、IA-AI（Python AI 服务）并行联调，
用于快速验证 AI 对话、SSE 事件流、工具调用轨迹与高危操作人工确认。

## 快速开始

```bash
cd web
npm install
cp .env.example .env.development   # 已有默认值，本地联调可跳过
npm run dev                        # http://localhost:5173
```

前置：IA-server 运行于 `http://localhost:8123`（context-path `/api`），
IA-AI 运行于 `http://localhost:8000`（已开启 CORS）。基址通过
`.env.development` 中的 `VITE_API_BASE_URL` / `VITE_AI_BASE_URL` 配置，
不要提交真实内网地址；生产环境用 Nginx 反向代理 `/api`。

## 页面

| 路由 | 功能 |
| --- | --- |
| `/` | AI 对话：打字机输出（SSE token）、Agent 执行轨迹时间线（tool_start / tool_end / expert_handoff / rag_retrieve）、高危操作确认卡片（approval_required → /api/chat/resume） |
| `/dashboard` | 环境数据看板：温湿度 / 光照 / CO₂ / 土壤湿度实时值与历史趋势（30s 轮询） |
| `/devices` | 设备列表与开关控制（带二次确认） |
| `/irrigation` | 湿度预测曲线（当前 / 2h / 4h / 6h）、预防性灌溉建议、灌溉启停与记录 |
| `/alarms` | 告警列表、级别标签、处理（可填备注），侧边栏未处理数角标 30s 刷新 |

## 技术说明

- SSE 消费：`/api/chat` 是 POST，EventSource 只支持 GET，
  故用 fetch + ReadableStream 解析 `data: {json}\n\n` 帧（`src/api/sse.ts`），
  支持 AbortController 中断（对话页"停止"按钮）、裸 token 帧兼容。
- 对话状态：Zustand 管理消息、执行轨迹（tool_start/tool_end 配对状态机）、
  审批状态（`src/stores/chatStore.ts`）；新会话时调用 `/api/chat/clear` 清理服务端历史。
- 全局状态：监测点跨页面共享并持久化（`src/stores/appStore.ts`）。
- 展示常量：工具中文名、设备/告警/灌溉枚举映射集中在 `src/utils/constants.tsx`。
- 图表：零依赖 SVG 折线图（`src/components/TrendChart.tsx`）。
- `_archive/`：另一套并行实现的归档备份，不参与构建，确认无误后可整体删除。
