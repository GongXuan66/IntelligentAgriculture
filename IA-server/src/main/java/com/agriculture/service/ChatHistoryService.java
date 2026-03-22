package com.agriculture.service;

import com.agriculture.entity.AiInteraction;
import com.agriculture.mapper.AiInteractionMapper;
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

    private final AiInteractionMapper aiInteractionMapper;
    private static final String TYPE_CHAT = "chat";

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
        AiInteraction history = new AiInteraction();
        history.setSessionId(sessionId);
        history.setRole(role);
        history.setContent(content);
        history.setInteractionType(TYPE_CHAT);
        aiInteractionMapper.insert(history);
        log.debug("保存对话历史: sessionId={}, role={}", sessionId, role);
    }

    /**
     * 获取会话的完整历史
     */
    public List<AiInteraction> getHistoryBySessionId(String sessionId) {
        return aiInteractionMapper.findBySessionId(sessionId);
    }

    /**
     * 分页获取会话历史
     */
    public Page<AiInteraction> getHistoryPaged(String sessionId, int pageNum, int pageSize) {
        Page<AiInteraction> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId)
                .eq(AiInteraction::getInteractionType, TYPE_CHAT)
                .orderByAsc(AiInteraction::getCreatedAt);
        return aiInteractionMapper.selectPage(page, wrapper);
    }

    /**
     * 获取最近N条历史
     */
    public List<AiInteraction> getRecentHistory(String sessionId, int limit) {
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId)
                .eq(AiInteraction::getInteractionType, TYPE_CHAT)
                .orderByDesc(AiInteraction::getCreatedAt)
                .last("LIMIT " + limit);
        return aiInteractionMapper.selectList(wrapper);
    }

    /**
     * 删除会话的所有历史
     */
    public void deleteBySessionId(String sessionId) {
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId);
        aiInteractionMapper.delete(wrapper);
        log.info("删除会话历史: sessionId={}", sessionId);
    }

    /**
     * 统计会话消息数
     */
    public Long countBySessionId(String sessionId) {
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId)
                .eq(AiInteraction::getInteractionType, TYPE_CHAT);
        return aiInteractionMapper.selectCount(wrapper);
    }
}