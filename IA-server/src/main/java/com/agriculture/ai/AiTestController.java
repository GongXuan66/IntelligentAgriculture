package com.agriculture.ai;

import com.agriculture.ai.client.IaAiClient;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * AI 助手控制器
 * 提供带记忆的流式对话能力
 */
@RestController
@RequestMapping("/ai")
@RequiredArgsConstructor
@Tag(name = "AI助手", description = "智慧农业AI对话接口")
public class AiTestController {

    private final IaAiClient iaAiClient;

    /**
     * 同步对话（POST，供前端调用）
     * @param request 请求体 {sessionId, message, context}
     * @return JSON 响应 {code, message, data: {reply, sessionId}}
     */
    @Operation(summary = "AI对话(同步)", description = "POST方式调用，返回完整JSON响应")
    @PostMapping(value = "/chat", produces = MediaType.APPLICATION_JSON_VALUE)
    public ResponseEntity<Map<String, Object>> chatSync(@RequestBody Map<String, String> request) {
        String sessionId = request.getOrDefault("sessionId", "");
        String message = request.getOrDefault("message", "你好");
        String context = request.getOrDefault("context", "");

        String normalizedSessionId = sessionId;
        if (normalizedSessionId == null || normalizedSessionId.isBlank()) {
            normalizedSessionId = "session_" + System.currentTimeMillis();
        }

        String fullMessage = buildFullMessage(message, context);
        IaAiClient.ChatSyncResult result = iaAiClient.chatSync(normalizedSessionId, fullMessage);

        Map<String, Object> data = new HashMap<>();
        data.put("reply", result.reply());
        data.put("sessionId", result.sessionId());

        Map<String, Object> response = new HashMap<>();
        response.put("code", 200);
        response.put("message", "success");
        response.put("data", data);

        return ResponseEntity.ok(response);
    }

    private String buildFullMessage(String message, String context) {
        if (context == null || context.isBlank()) {
            return message;
        }
        return "【当前环境数据】\n" + context + "\n\n【用户问题】\n" + message;
    }

    /**
     * 流式对话（SSE）
     * @param message 用户消息
     * @param sessionId 会话ID（可选，传入则启用记忆和历史记录）
     * @return 流式响应
     */
    @Operation(summary = "AI对话(流式)", description = "支持流式响应，传入sessionId启用对话记忆")
    @GetMapping(value = "/chat/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<String> chatStream(
            @Parameter(description = "用户消息") 
            @RequestParam(value = "message", defaultValue = "你好") String message,
            @Parameter(description = "会话ID，传入则启用记忆") 
            @RequestParam(value = "sessionId", required = false) String sessionId) {
        
        return Flux.just("data: {\"error\":\"IA-AI 暂不支持后端转发流式对话\"}\n\n");
    }

    /**
     * 获取会话的对话历史
     */
    @Operation(summary = "获取对话历史", description = "获取指定会话的完整对话记录")
    @GetMapping("/history")
    public ResponseEntity<Map<String, Object>> getHistory(
            @Parameter(description = "会话ID")
            @RequestParam("sessionId") String sessionId) {
        Map<String, Object> response = new HashMap<>();
        response.put("code", 501);
        response.put("message", "对话历史已由 IA-AI 维护");
        response.put("data", List.of());
        return ResponseEntity.status(501).body(response);
    }

    /**
     * 清除指定会话的记忆和历史
     * @param sessionId 会话ID
     * @return 操作结果
     */
    @Operation(summary = "清除记忆", description = "清除指定会话的对话历史")
    @DeleteMapping("/memory")
    public String clearMemory(
            @Parameter(description = "会话ID")
            @RequestParam("sessionId") String sessionId) {
        iaAiClient.clearSession(sessionId);
        return "已清除会话 [" + sessionId + "] 的记忆";
    }
}
