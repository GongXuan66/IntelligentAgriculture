# 智慧农业项目 AI 优化计划

> 记录时间：2026-09-13
> 目标：参考《AI 零代码应用生成平台》教程的企业级 AI 工程实践，补齐本项目在 Agent 工程化、RAG 检索质量、效果验证上的短板，并新增 React Web 前端用于快速验证。

---

## 进度记录

- **2026-09-13 ~ 09-16（已完成）**：SSE 多事件流（`main.py` 已产出 token / tool_start / tool_end / expert_handoff / rag_retrieve / approval_required / done / error 全事件）；高危写操作人在环路（LangGraph interrupt + `/api/chat/resume`）；Expert 子 Agent 嵌套 asyncio 修复（`run_expert` 全链路异步）。
- **2026-09-22（已完成）**：RAG 余弦距离修复——`vector_store.py` 创建 collection 指定 `hnsw:space=cosine` 并对旧 L2 索引告警；`config.py` 阈值 0.1 → 0.5；切分 `keep_separator=True` + 短块过滤（`min_chunk_length=10`）；空检索硬兜底（固定文案"知识库中未查询到相关内容" + 主 Agent 提示词禁止编造约束）；新增 `scripts/rebuild_index.py` 重建脚本。**待办**：旧索引需在有 embedding 能力的环境执行重建（配 ModelScope Embedding API Key 或在装了 torch 的机器上跑），重建后按实测分布复核阈值（预计 0.5~0.7）。
- **2026-09-22（第二批已完成）**：
  - Query 侧优化：新增 `app/rag/query_processor.py`（指代改写——检测到"它/这个/那块地"且有对话历史才调 LLM；Multi-Query 改写，可用 `RAG_QUERY_REWRITE_MODEL` 配小模型控成本）+ `app/rag/synonyms.py`（农业领域同义词规则扩展，已实测）。
  - 混合检索：新增 `app/rag/hybrid.py`（BM25[jieba 分词] + 向量粗召回，RRF 融合，语料与向量库同源），依赖 `rank-bm25`、`jieba` 已入 pyproject。
  - 确定性来源标注：Markdown 按标题层级切分（`MarkdownHeaderTextSplitter`，标题写入 metadata），工具返回的"文档名 > 章节"来源由代码拼接，不经模型。
  - 同源分块补全：分块按来源编号 `chunk_index`，命中后回填同文档前后各 1 块合并（老索引无此元数据时自动降级）。
  - 输入/输出护轨：新增 `app/guardrails/`——输入侧注入特征 + 越权指令正则拦截（接入 `/api/chat`、`/api/chat/sync`，已实测含误拦用例）；输出侧只读工具失败特征识别 + 自动重试包装（`tool_registry` 接入，RAG 与高危写工具除外）。
  - 知识库语料扩充：新增 `data/documents/guide/` 四份指南（作物生育期灌溉、病虫害防治、设备故障排查、气象农事），由原来 2 份增至 6 份。
  - **待办**：`uv sync` 安装新依赖；重建索引（同第一批待办，一次重建同时满足两批）；高危操作"前后端联动"依赖 React 前端（第一批剩余项）。
- **2026-09-22（React Web 前端已完成）**：新增 `web/`（React 18 + TS + Vite + AntD + Zustand）。AI 对话页（打字机输出、执行轨迹时间线 start/end 配对、高危操作确认卡片、停止按钮、建议问题、新会话清理服务端历史）；数据看板（五项环境指标 + 历史趋势，30s 轮询）；设备管理（开关控制，设备状态枚举已与后端对齐）；智能灌溉（湿度预测 2h/4h/6h 曲线、智能决策方案、策略展示、累计水量、灌溉记录启停）；告警中心（列表、级别/状态映射、处理备注、侧边栏未处理角标）。目录中曾出现两套并行实现，已择优合并为一套并将另一套归档至 `web/_archive/`。**待办**：依赖安装后 `pnpm dev` 联调验证。
- **2026-09-22（第三批已完成）**：
  - 真实 Rerank：`reranker.py` 从占位实现改为 bge-reranker-base（CrossEncoder）本地精排，懒加载、缺依赖自动降级；接入混合检索（粗召回 10 条精排取 3）；默认关闭，`RAG_RERANK_ENABLED=true` 启用。
  - RAG 评测集：`eval/rag_eval_dataset.json` 37 条标注（问题→期望文档块），`scripts/eval_rag.py` 统计 Hit Rate/MRR，支持 vector / hybrid / hybrid+rerank 三模式对比（简历"优化前后"数字来源）。
  - 限流：`app/guardrails/rate_limit.py` IP/会话/全局三级令牌桶（已实测），接入 `/api/chat`（429 结构化拒绝），限额走环境变量。
  - 模型分级路由：`app/agent/model_router.py` 保守白名单规则（闲聊/天气/单点读数→小模型，其余→主模型，已实测），`OPENAI_SMALL_MODEL` 未配置时全部走主模型。
  - Token 统计：`app/observability/token_stats.py` 从 `on_chat_model_end` 收集 usage_metadata，明细写 `logs/token_usage.jsonl`，聚合经 `GET /api/stats` 暴露。
  - 灌溉决策工作流化：新增 `app/workflows/irrigation_graph.py`，StateGraph 六节点（predict→risk→decide→条件边→review(interrupt 人审)→execute→learn 学习回写），决策规则与 Java 一致、水量计算复用 Java plan 接口；`POST /api/irrigation/workflow/run` + `/resume` SSE 接口。
  - 路由评测：`eval/agent_routing_dataset.json` 32 条问句（4 专家 + 天气/告警/监测点/知识库），`scripts/eval_agent_routing.py` 统计整体与分类路由准确率。
  - **待办（需运行环境）**：跑 `eval_rag.py` 三模式对比 + `eval_agent_routing.py`，用实测数字填简历；rerank 需 sentence-transformers + 模型下载；工作流接口可在 Web 前端加触发入口。
- **2026-09-24（依赖调整）**：`sentence-transformers` 从硬依赖移到可选依赖 `local-embed`（`uv sync` 不再连带安装 torch；独显机器用 `uv sync --extra local-embed`）。本机 embedding 走 ModelScope API（配 `RAG_EMBEDDING_API_KEY`），缺依赖时的报错信息已带引导。

---

## 一、Agent 工程化优化

### 1. SSE 多事件流（优先级高，改动小、演示效果强）

- **现状**：IA-AI 的 `POST /api/chat` 只推送 `{"token": ...}`，工具调用、专家分派、RAG 检索过程对用户是黑盒。
- **改造**：定义统一事件载体，增加 `event` 字段，区分：
  - `token`：模型流式输出
  - `tool_start` / `tool_end`：工具调用开始 / 结束（含工具名、参数、结果摘要）
  - `expert_handoff`：主 Agent 分派到哪个领域专家
  - `rag_retrieve`：RAG 检索命中文档与分数
  - `error`：结构化错误信息
  - `done`：结束标记
- **前端配合**：对话界面展示"正在调用灌溉专家 → 正在查询湿度预测"的执行轨迹。
- **涉及文件**：`IA-AI/app/main.py`、`app/agent/assistant.py`（astream_events 事件监听）

### 2. 输入 / 输出护轨（Guardrail）

- **现状**：无任何 Prompt 注入防护，用户可诱导模型直接调用 `start_irrigation` 等高危工具；工具失败仅把异常转成中文文本回喂模型，无结构化重试。
- **改造**：
  - 输入侧：敏感词 + 注入特征规则拦截，拒绝越权指令。
  - 输出侧：对工具执行结果做校验，失败时按策略自动重试。
- **涉及文件**：新增 `IA-AI/app/guardrails/` 模块，在 chat 入口处接入。

### 3. 高危写操作"人在环路"二次确认（Human-in-the-loop）

- **现状**：`control_device`、`start_irrigation` 等工具模型可直接执行（farm 写操作目前靠"不注册给 Agent"规避）。
- **改造**：利用 LangGraph 的 interrupt 机制，写操作先返回"待确认"事件，用户确认后恢复执行。
- **价值**：比单纯收敛工具更完整的安全方案，也是 Checkpointer 的核心应用场景。

### 4. AI 接口限流 + 成本控制

- **现状**：`/api/chat` 无限流，存在 Token 被刷爆的风险。
- **改造**：
  - 用户 / IP / 会话三级令牌桶限流（Python 侧可用 Redis 实现，或在 IA-server 网关层做）。
  - 模型分级路由：意图分类、关键词路由等简单任务走小模型（如 Qwen-Turbo），专家工具调用与农事建议走 Kimi-K2.5。
  - 记录每次请求的 Token 用量与耗时，为成本分析和可观测性提供数据。

### 5. 智能灌溉决策链升级为 LangGraph 工作流

- **现状**：`SmartIrrigationServiceImpl.buildSmartPlan()` 是 Java 侧写死的串行逻辑。
- **改造**：在 IA-AI 侧（或 IA-server 用 LangGraph4j）抽象为 StateGraph：
  `湿度预测 → 生育期 / 环境风险系数计算 → 条件边决策（自适应灌溉 / 预测式灌溉 / 不灌）→ 人审 → 执行 → 在线学习回写`
- **价值**：简历同时具备"对话型多 Agent"和"编排型工作流"两种 LangGraph 形态。

### 6. 修复 Expert 子 Agent 的嵌套事件循环问题

- **现状**：`app/agent/experts/` 的工具内用 `asyncio.run()` 同步驱动子 Agent，在 FastAPI 已有事件循环时存在嵌套循环风险。
- **改造**：改为 `await run_expert(...)` 全链路异步。
- **备注**：面试深挖多 Agent 实现时容易暴露，优先修复。

---

## 二、RAG 检索质量优化

> 结论：**不换向量库**。当前知识库仅 2 个文档、151 行、向量库 2.1MB，ChromaDB 完全够用；Milvus 属于过度设计，pgvector 仅在需要"统一存储 + SQL 一体化混合检索"时才考虑。

### 1. 修复相似度计算（优先级最高，现有实现有数学错误）

- **现状**：`app/rag/retriever.py` 中用 `similarity = 1 - score`，但 Chroma 默认是 **L2 距离**，`1 - L2` 不代表余弦相似度；阈值 0.1 过低，等于所有结果都放行。
- **改造**：
  - 建 collection 时指定 `hnsw:space=cosine`（bge-small-zh 已做向量归一化，应配余弦距离）。
  - 清空并重建索引，按实测重设阈值（预计 0.5 ~ 0.7）。
- **涉及文件**：`app/rag/vector_store.py`、`app/rag/retriever.py`、`app/rag/config.py`

### 2. 扩充知识库语料

- **现状**：仅 FAQ + 设备操作手册 151 行，chunk 数太少，RAG 退化为"全量文档塞给模型"。
- **改造**：补充作物各生育期灌溉指南、常见病虫害、设备故障排查、气象农事建议等，目标几百个 chunk 以上。

### 3. 混合检索（BM25 + 向量，零新增基建）

- **改造**：并行使用 `BM25Retriever`（关键词召回）与 Chroma 向量检索（语义召回），用 **RRF 倒数排名融合**合并结果。
- **解决问题**：中文短 query（如"风扇不转怎么办"）纯向量容易漏掉关键词匹配。

### 4. Rerank 从占位变为真实实现

- **现状**：`app/rag/model/reranker.py` 是空实现，`rerank_enabled` 默认关闭。
- **改造**：接入本地 **bge-reranker-base / bge-reranker-v2-m3**（可离线运行），粗召回 top-10 后精排取 top-3。
- **注意**：在真实上线前，简历和面试口径统一为"纯向量 + 阈值过滤"，不能声称已有 rerank。

### 5. 建立 RAG 评测集

- 准备约 30 条"问题 → 应命中文档块"标注集。
- 指标：Hit Rate、MRR；用优化前后的数字支撑简历描述。

### 6. 借鉴 CampusKnowledge_QASystem 的 Query 侧优化

> 参考项目 `/Users/gongxuan/Documents/Project/CampusKnowledge_QASystem/`。它的向量库与切分并无优势（同样无 BM25/rerank、用 L2 距离），但检索前的 Query 处理和检索后的确定性处理值得借鉴。

- [ ] **Query 改写 / Multi-Query 检索**：在 `rag_tools.search_knowledge_base` 内部，用便宜小模型将用户问题改写为 2 ~ 3 条更精准的检索 query，并行向量检索后去重合并；复杂问题支持子问题拆分检索。
- [ ] **农业领域同义词扩展**：维护领域词典（如 西红柿/番茄、滴灌/灌溉、抽穗/生育期），对检索词做扩展，替代参考项目中与 MySQL LIKE 强耦合的 jieba 关键词方案。
- [ ] **空检索硬兜底（优先级高，改动最小）**：检索结果为空时工具返回固定中文提示"知识库中未查询到相关内容"，并在主 Agent 提示词中约束此时不得编造；参考项目此时直接不调用 LLM。
- [ ] **确定性来源标注**：工具返回内容由代码拼接"文档名 + 章节标题 + 内容"，Markdown 切分时把标题层级写入 metadata；来源不允许模型生成，防止虚构引用。
- [ ] **同源分块补全（small-to-big 简化版）**：命中某文档少量分块时，回填同章节相邻块（如前后各 1 块）后合并，避免答案被 chunk 边界截断。
- [ ] **多轮指代改写**：利用 thread 历史，在 RAG 工具内将"它 / 这个设备 / 那块地"等指代替换为具体实体后再检索。
- [ ] **切分细节对齐**：`RecursiveCharacterTextSplitter` 设置 `keep_separator=True` 保留句末标点，过滤无意义短块。
- [ ] **成本权衡参考**：同步链路可用小模型做 query 分析；若未来在高并发流式场景，可退化为本地规则分析，避免多一次 LLM 往返延迟。

### 7. 明确不照搬参考项目的内容

- Milvus：数据量不需要，继续用 Chroma。
- MySQL LIKE 双源检索：本项目结构化数据（作物生育期、阈值等）已由 27 个业务工具承载，不再重复建设关键词 SQL 检索。
- 参考项目同样缺少 BM25 / RRF / rerank / 评测集，本项目按第 3、4、5 点做完会比它更完整。

### 8. 暂不做的内容

- HyDE、多索引路由：当前语料规模下收益有限，待知识库扩充后再评估。
- 迁移 Milvus：数据量级完全不需要。
- 迁移 pgvector：仅当决定做"`tsvector` 全文检索 + pgvector 语义召回 + SQL 内 RRF 融合"的统一存储方案时才执行，单纯平移无意义。

---

## 三、需要补的量化数据

简历目前没有任何实测数字，参考教程的做法补齐：

- [ ] 构造 30 ~ 50 条典型问句，统计 4 个专家的**路由准确率**、27 个工具的**调用触发率**，给出优化前后对比。
- [ ] RAG 检索命中率（Hit Rate / MRR，见上）。
- [ ] Token 用量与接口耗时统计，落库或输出指标日志。

> 禁止编造数字；所有指标必须来自真实跑测。

---

## 四、新增 React Web 前端

### 背景

现有前端为 HarmonyOS（ArkTS + ArkUI，位于 `app/`），运行依赖 DevEco Studio / hvigorw 工具链，不便快速验证 AI 对话、SSE 事件流、工具调用轨迹、人审确认等效果。因此新增一套常规 React Web 前端，与 IA-server / IA-AI 并行联调。

### 技术选型（建议）

- React 18 + TypeScript + Vite
- UI 组件库：Ant Design
- 状态管理：Zustand
- 请求：原生 EventSource / fetch stream 消费 SSE
- 目录建议：项目根新增 `web/`（与 `app/`、`IA-AI/`、`IA-server/` 平级）

### 核心页面 / 功能

- [ ] AI 对话页：打字机效果，消费 SSE `token` 事件
- [ ] Agent 执行轨迹展示：解析 `tool_start / tool_end / expert_handoff / rag_retrieve` 事件，时间线形式呈现
- [ ] 高危操作确认卡片：接收"待确认"事件，用户点击后调接口恢复 LangGraph 执行
- [ ] 设备列表与控制、环境数据看板（温湿度 / 光照 / CO₂ / 土壤湿度）
- [ ] 灌溉记录与智能灌溉策略展示（含湿度预测曲线 2h/4h/6h）
- [ ] 告警列表与处理

### 配置约定

- API 基址通过 `.env` 区分环境（`VITE_API_BASE_URL`），不提交真实内网地址。
- IA-AI 已开启 CORS，本地联调直连 `http://localhost:8000`；生产通过 Nginx 反向代理 `/api`。

---

## 五、实施顺序建议

1. **第一批（半天 ~ 1 天 / 项，收益最大）**
  - 修复 RAG 余弦距离配置并重建索引
  - RAG 空检索硬兜底 + 切分 `keep_separator` 对齐
  - SSE 多事件流
  - 修复 Expert 嵌套 asyncio
  - React Web 前端初始化 + AI 对话页
2. **第二批**
  - Query 改写 / Multi-Query + 农业同义词扩展 + 多轮指代改写
  - 确定性来源标注 + 同源分块补全
  - 输入 / 输出护轨
  - 高危操作人在环路（前后端联动）
  - BM25 混合检索
  - 扩充知识库语料
3. **第三批**
  - 真实 Rerank + RAG 评测集
  - 限流 + 模型分级路由 + Token 统计
  - 灌溉决策 LangGraph 工作流化
  - 路由准确率 / 工具触发率评测

---

## 六、简历风险点备忘（面试口径）

1. Java 侧 LangChain4j `Assistant` 代码完整，但**线上对话主链路是转发到 Python IA-AI 服务**，Java 流式端点仍是占位。口径："两套方案都做了落地验证，线上主链路是 Python 服务"。
2. RAG 当前**没有 rerank、没有混合检索**，在第二、三批改造完成前不得写成已上线能力。
3. 所有百分比、耗时类数字必须有实测来源。
