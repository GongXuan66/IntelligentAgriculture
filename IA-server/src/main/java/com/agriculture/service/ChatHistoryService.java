package com.agriculture.service;

import com.agriculture.entity.ChatHistory;
import com.agriculture.mapper.ChatHistoryMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class ChatHistoryService {

    private final ChatHistoryMapper chatHistoryMapper;

    /**
     * 保存用户消息
     */
    public void saveUserMessage(String sessionId, String content) {
        saveMessage(sessionId, "user", content);
    }

    /**
     * 保存助手消息
     */
    public void saveAssistantMessage(String sessionId, String content) {
        saveMessage(sessionId, "assistant", content);
    }

    /**
     * 异步保存消息（不阻塞流式响应）
     */
    @Async
    public void saveMessageAsync(String sessionId, String role, String content) {
        saveMessage(sessionId, role, content);
    }

    /**
     * 保存消息
     */
    private void saveMessage(String sessionId, String role, String content) {
        ChatHistory history = new ChatHistory();
        history.setSessionId(sessionId);
        history.setRole(role);
        history.setContent(content);
        chatHistoryMapper.insert(history);
        log.debug("保存对话历史: sessionId={}, role={}", sessionId, role);
    }

    /**
     * 获取会话的完整历史
     */
    public List<ChatHistory> getHistoryBySessionId(String sessionId) {
        return chatHistoryMapper.findBySessionIdOrderByCreatedAtAsc(sessionId);
    }

    /**
     * 分页获取会话历史
     */
    public Page<ChatHistory> getHistoryPaged(String sessionId, int pageNum, int pageSize) {
        Page<ChatHistory> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<ChatHistory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ChatHistory::getSessionId, sessionId)
                .orderByAsc(ChatHistory::getCreatedAt);
        return chatHistoryMapper.selectPage(page, wrapper);
    }

    /**
     * 获取最近N条历史
     */
    public List<ChatHistory> getRecentHistory(String sessionId, int limit) {
        return chatHistoryMapper.findRecentBySessionId(sessionId, limit);
    }

    /**
     * 删除会话的所有历史
     */
    public void deleteBySessionId(String sessionId) {
        LambdaQueryWrapper<ChatHistory> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(ChatHistory::getSessionId, sessionId);
        chatHistoryMapper.delete(wrapper);
        log.info("删除会话历史: sessionId={}", sessionId);
    }

    /**
     * 统计会话消息数
     */
    public Long countBySessionId(String sessionId) {
        return chatHistoryMapper.countBySessionId(sessionId);
    }
}
