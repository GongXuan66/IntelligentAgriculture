# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a smart agriculture management system with three main components:

- **IA-server/**: Spring Boot 3.x backend (Java 17) - core business logic and API
- **app/**: HarmonyOS/OpenHarmony frontend (ArkTS + ArkUI) - mobile application
- **IA-AI/**: Python AI service (FastAPI + LangChain) - AI assistant with RAG and tool calling

## Common Commands

### Backend (IA-server)
```bash
cd IA-server
mvn spring-boot:run          # Run the application
mvn compile                  # Compile without tests
mvn test                     # Run tests
mvn clean package -DskipTests # Build production JAR
```

### Frontend (app)
```bash
cd app
hvigorw assembleHap          # Build installable HAP
hvigorw clean                # Clear build artifacts
hvigorw test                 # Run unit tests
```

### AI Service (IA-AI)
```bash
cd IA-AI
pip install -r requirements.txt  # Install dependencies (if needed)
python -m app.main               # Run the FastAPI server
# API available at http://localhost:8000
# API docs at http://localhost:8000/docs
```

## Architecture

### Backend Stack (IA-server)
- Spring Boot 3.2.3 with MyBatis-Plus 3.5.9
- MySQL 8.0+ for persistence
- Redis 7.0+ and Caffeine for caching
- LangChain4j for AI integration (ModelScope Kimi-K2.5)
- ONNX Runtime for ML inference (LSTM moisture prediction)
- Knife4j for API documentation at `/api/doc.html`

### AI Service Stack (IA-AI)
- FastAPI with uvicorn for async HTTP
- LangChain + LangGraph for LLM agent orchestration
- ChromaDB for vector storage (RAG)
- sentence-transformers for text embeddings
- HTTP clients to communicate with IA-server

### Frontend Stack (app)
- ArkTS + ArkUI (declarative UI)
- Hypium + Hamock for testing

### API Configuration
- Base URL: `/api`
- Default port: 8123 (configurable via `SERVER_PORT`)
- MySQL: `jdbc:mysql://localhost:3306/agriculture`
- Redis: `127.0.0.1:6379`
- AI Service: port 8000

### Key Backend Services
- `SmartIrrigationService` - core irrigation orchestration
- `MoisturePredictor` / `ONNXPredictor` - ML-based prediction
- `IrrigationLearningService` - adaptive learning
- `AI` module - LangChain4j-based AI assistant with tool calling

### Key AI Service Modules (IA-AI)
- `app/agent/` - LangChain agent with tool calling
- `app/tools/` - Device, irrigation, environment, alarm, weather tools
- `app/rag/` - RAG engine with ChromaDB vector store
- `app/services/clients/` - HTTP clients to IA-server
- `app/memory/` - Session management for conversation history

## Database
MySQL is required. Key tables: `farm`, `device`, `sensor_data`, `monitor_point`, `irrigation_log`, `alarm`, `crop_type`, `crop_planting`, `crop_stage_config`, `irrigation_threshold_config`.