package com.agriculture.ai;

import com.agriculture.entity.ChatHistory;
import com.agriculture.service.ChatHistoryService;
import dev.langchain4j.store.memory.chat.ChatMemoryStore;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Flux;

import java.util.List;

/**
 * AI 助手控制器
 * 提供带记忆的流式对话能力
 */
@RestController
@RequestMapping("/ai")
@RequiredArgsConstructor
@Tag(name = "AI助手", description = "智慧农业AI对话接口")
public class AiTestController {

    private final Assistant assistant;
    private final ChatMemoryStore chatMemoryStore;
    private final ChatHistoryService chatHistoryService;

    /**
     * 流式对话（SSE）
     * @param message 用户消息
     * @param sessionId 会话ID（可选，传入则启用记忆和历史记录）
     * @return 流式响应
     */
    @Operation(summary = "AI对话", description = "支持流式响应，传入sessionId启用对话记忆")
    @GetMapping(value = "/chat", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<String> chat(
            @Parameter(description = "用户消息") 
            @RequestParam(value = "message", defaultValue = "你好") String message,
            @Parameter(description = "会话ID，传入则启用记忆") 
            @RequestParam(value = "sessionId", required = false) String sessionId) {
        
        if (sessionId != null && !sessionId.isBlank()) {
            // 带记忆的对话：保存用户消息，收集助手响应后保存
            chatHistoryService.saveUserMessage(sessionId, message);
            return collectAndSaveResponse(sessionId, assistant.chat(sessionId, message));
        } else {
            // 无记忆的一次性对话
            return assistant.chat(message);
        }
    }

    /**
     * 收集流式响应并保存到历史记录
     */
    private Flux<String> collectAndSaveResponse(String sessionId, Flux<String> responseFlux) {
        StringBuilder fullResponse = new StringBuilder();
        return responseFlux
                .doOnNext(fullResponse::append)
                .doOnComplete(() -> {
                    // 流完成后保存助手消息
                    if (!fullResponse.isEmpty()) {
                        chatHistoryService.saveAssistantMessage(sessionId, fullResponse.toString());
                    }
                });
    }

    /**
     * 获取会话的对话历史
     */
    @Operation(summary = "获取对话历史", description = "获取指定会话的完整对话记录")
    @GetMapping("/history")
    public List<ChatHistory> getHistory(
            @Parameter(description = "会话ID") 
            @RequestParam("sessionId") String sessionId) {
        return chatHistoryService.getHistoryBySessionId(sessionId);
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
        // 清除 Redis 记忆
        chatMemoryStore.deleteMessages(sessionId);
        // 清除数据库历史
        chatHistoryService.deleteBySessionId(sessionId);
        return "已清除会话 [" + sessionId + "] 的记忆和历史";
    }
}
