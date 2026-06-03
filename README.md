# 智慧农业控制系统

<p align="center">
  <img src="https://img.shields.io/badge/OpenHarmony-3.2%20Release-blue" alt="OpenHarmony">
  <img src="https://img.shields.io/badge/Spring%20Boot-3.2.3-brightgreen" alt="Spring Boot">
  <img src="https://img.shields.io/badge/Python-FastAPI-orange" alt="FastAPI">
  <img src="https://img.shields.io/badge/License-Apache%202.0-yellow" alt="License">
</p>


> 基于 OpenHarmony + Spring Boot + LangChain 的智慧农业管理平台

## 项目简介

本项目是一款面向智慧农业的综合性管理平台，整合物联网传感、智能灌溉、环境监测、设备控制、AI辅助决策等功能，实现农业生产的数字化、智能化管理。

### 核心特性

- 🌱 **智能灌溉** - EWMA预测算法 + LSTM深度学习模型，实现预测性灌溉
- 🤖 **AI智能助手** - 基于LangChain4j + Kimi大模型，支持自然语言控制设备
- 📱 **原生应用** - 基于HarmonyOS/OpenHarmony开发的移动应用
- ☁️ **云边端协同** - 云服务器 + 边缘网关 + 移动终端三层架构

## 系统架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                           云服务器层                                 │
│              (Spring Boot 3.x + MySQL + Redis)                      │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────────┐   │
│  │  多租户管理   │  │  智能算法    │  │    LangChain4j AI     │   │
│  │  用户认证     │  │  灌溉决策    │  │    Kimi-K2.5 大模型   │   │
│  └──────────────┘  └──────────────┘  └────────────────────────┘   │
└────────────────────────────────┬────────────────────────────────────┘
                                 │ HTTP REST API
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  RK2206 开发板  │    │  RK2206 开发板  │    │  HarmonyOS APP  │
│   (边缘网关)    │    │   (边缘网关)    │    │    (手机端)     │
│                 │    │                 │    │                 │
│  数据采集       │    │  数据采集       │    │  远程监控       │
│  设备控制       │    │  设备控制       │    │  手动操作       │
│  数据上报       │    │  数据上报       │    │  AI对话         │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 项目组成

```
IntelligentAgriculture/
├── IA-server/          # Spring Boot 后端服务 (Java 17)
├── app/                # HarmonyOS/OpenHarmony 前端应用 (ArkTS)
├── IA-AI/              # Python AI 服务 (FastAPI + LangChain)
├── docs/               # 系统设计文档
├── 需求文档/           # 需求分析文档
└── ml-models/          # 机器学习模型
```

## 技术栈

### 后端 (IA-server)

| 技术         | 版本        | 用途       |
| ------------ | ----------- | ---------- |
| Spring Boot  | 3.2.3       | 应用框架   |
| MyBatis-Plus | 3.5.9       | ORM框架    |
| MySQL        | 8.0+        | 关系数据库 |
| Redis        | 7.0+        | 缓存       |
| LangChain4j  | 1.3.0-beta9 | AI集成     |
| ONNX Runtime | 1.16+       | ML推理     |

### 前端 (app)

| 技术            | 用途         |
| --------------- | ------------ |
| ArkTS           | 开发语言     |
| ArkUI           | 声明式UI框架 |
| OpenHarmony 3.2 | 目标系统     |

### AI服务 (IA-AI)

| 技术                  | 用途      |
| --------------------- | --------- |
| FastAPI               | Web框架   |
| LangChain             | Agent编排 |
| ChromaDB              | 向量存储  |
| sentence-transformers | 文本嵌入  |

## 功能模块

### 1. 环境监测

- 温度、湿度、土壤湿度实时监测
- 光照强度、CO2浓度监测
- 历史数据图表展示

### 2. 智能灌溉

- **三层算法架构**：
  - Layer 1: 环境因子调整
  - Layer 2: 作物生长阶段感知
  - Layer 3: 预测性灌溉 (EWMA + LSTM)
- 自动/手动灌溉模式
- 灌溉效果追踪与分析

### 3. 设备控制

- 水泵、风机、LED补光灯控制
- 设备状态实时监控
- 联动规则配置

### 4. AI智能助手

- 自然语言对话
- 设备控制（语音/文字）
- 智能推荐与报警

### 5. 报警管理

- 环境异常阈值报警
- 设备故障报警
- 报警历史记录

## 快速开始

### 前置要求

- JDK 17+
- Maven 3.8+
- MySQL 8.0+
- Redis 7.0+
- Node.js 18+ (for AI service)

### 1. 克隆项目

```bash
git clone https://github.com/your-repo/IntelligentAgriculture.git
cd IntelligentAgriculture
```

### 2. 启动后端服务

```bash
cd IA-server

# 配置数据库连接
# 编辑 src/main/resources/application.yml

# 启动服务
mvn spring-boot:run
```

服务启动后访问: http://localhost:8123/api/doc.html

### 3. 启动AI服务 (可选)

```bash
cd IA-AI

# 安装依赖
pip install -r requirements.txt

# 启动服务
python -m app.main
```

AI服务访问: http://localhost:8000/docs

### 4. 构建前端应用

```bash
cd app

# 使用 DevEco Studio 打开项目
# 构建 HAP 安装包
hvigorw assembleHap
```

## 智能灌溉算法详解

### 四层决策架构

```
┌─────────────────────────────────────────────────────────────┐
│           Layer 4: 作物生长阶段感知层                         │
│        根据作物类型和生长周期，动态调整灌溉策略                │
├─────────────────────────────────────────────────────────────┤
│           Layer 3: 预测性灌溉决策层                          │
│        EWMA 时序预测 + LSTM 深度学习预测                      │
├─────────────────────────────────────────────────────────────┤
│           Layer 2: 多目标优化层                              │
│        NSGA-II 算法，综合考虑节水/作物健康/成本               │
├─────────────────────────────────────────────────────────────┤
│           Layer 1: 自适应学习层                              │
│        根据灌溉效果持续优化模型参数                           │
└─────────────────────────────────────────────────────────────┘
```

### 预置作物知识库

系统内置10种作物生长阶段配置：

| 作物 | 阶段数 | 特点                     |
| ---- | ------ | ------------------------ |
| 番茄 | 5阶段  | 播种→幼苗→开花→结果→成熟 |
| 黄瓜 | 4阶段  | 喜湿作物，需水量大       |
| 辣椒 | 4阶段  | 开花期敏感               |
| 草莓 | 4阶段  | 收获期控水提质           |
| 西瓜 | 5阶段  | 成熟期控水提高糖度       |

## AI助手能力

基于LangChain4j和Kimi大模型，实现以下能力：

### 工具调用 (Function Calling)

- 查询设备状态
- 控制设备开关
- 获取环境数据
- 启动/停止灌溉
- 查询报警信息

### 自然语言示例

```
用户："帮我打开一号水泵"
AI → 调用 DeviceTools → 执行控制 → 返回结果

用户："今天需要灌溉吗"
AI → 查询环境数据 → 分析决策 → 返回建议
```

## 数据库设计

### 核心表结构 (17张)

```
用户与租户: user, farm
基础业务: monitor_point, device, sensor_data, irrigation_log, alarm
智能灌溉: crop_type, crop_stage_config, crop_planting, irrigation_threshold_config
AI功能: chat_history, ai_recommendation, ai_analysis_report
系统配置: system_config, device_control_log
```

### 多租户数据隔离

```
user (用户)
  └── farm (农场)
         └── monitor_point (检测点)
                ├── device (设备)
                ├── sensor_data (传感器数据)
                └── irrigation_log (灌溉记录)
```

## 项目截图

| 首页                          | 灌溉控制                            | 设备管理                        | AI助手                    |
| ----------------------------- | ----------------------------------- | ------------------------------- | ------------------------- |
| ![首页](docs/images/home.png) | ![灌溉](docs/images/irrigation.png) | ![设备](docs/images/device.png) | ![AI](docs/images/ai.png) |

## 比赛创新亮点

1. **预测性灌溉** - EWMA算法预测未来湿度，实现预防性灌溉
2. **作物生长阶段感知** - 根据作物生长周期动态调整灌溉策略
3. **AI工具调用** - 自然语言直接控制设备，无需菜单操作
4. **双模式预测** - EWMA保底 + LSTM深度学习灵活切换
5. **国产化生态** - 基于OpenHarmony + 鸿蒙系统

## 贡献指南

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -m 'Add xxx'`)
4. 推送分支 (`git push origin feature/xxx`)
5. 创建 Pull Request

## 许可证

Apache License 2.0 - see [LICENSE](LICENSE) for details

## 致谢

- [OpenHarmony](https://www.openharmony.cn/) - 开放原子开源基金会
- [Spring Boot](https://spring.io/projects/spring-boot) - Pivotal
- [LangChain4j](https://github.com/langchain4j/langchain4j) - Java AI框架
- [ModelScope](https://modelscope.cn/) - 魔搭社区

---

<p align="center">Made with ❤️ for Smart Agriculture</p>
