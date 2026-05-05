package com.agriculture.service.impl;

import com.agriculture.entity.AiInteraction;
import com.agriculture.mapper.AiInteractionMapper;
import com.agriculture.service.ChatHistoryService;
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
public class ChatHistoryServiceImpl implements ChatHistoryService {

    private final AiInteractionMapper aiInteractionMapper;
    private static final String TYPE_CHAT = "chat";

    @Override
    public void saveUserMessage(String sessionId, String content) {
        saveMessage(sessionId, "user", content);
    }

    @Override
    public void saveAssistantMessage(String sessionId, String content) {
        saveMessage(sessionId, "assistant", content);
    }

    @Override
    @Async
    public void saveMessageAsync(String sessionId, String role, String content) {
        saveMessage(sessionId, role, content);
    }

    private void saveMessage(String sessionId, String role, String content) {
        AiInteraction history = new AiInteraction();
        history.setSessionId(sessionId);
        history.setRole(role);
        history.setContent(content);
        history.setInteractionType(TYPE_CHAT);
        aiInteractionMapper.insert(history);
        log.debug("保存对话历史: sessionId={}, role={}", sessionId, role);
    }

    @Override
    public List<AiInteraction> getHistoryBySessionId(String sessionId) {
        return aiInteractionMapper.findBySessionId(sessionId);
    }

    @Override
    public Page<AiInteraction> getHistoryPaged(String sessionId, int pageNum, int pageSize) {
        Page<AiInteraction> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId)
                .eq(AiInteraction::getInteractionType, TYPE_CHAT)
                .orderByAsc(AiInteraction::getCreatedAt);
        return aiInteractionMapper.selectPage(page, wrapper);
    }

    @Override
    public List<AiInteraction> getRecentHistory(String sessionId, int limit) {
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId)
                .eq(AiInteraction::getInteractionType, TYPE_CHAT)
                .orderByDesc(AiInteraction::getCreatedAt)
                .last("LIMIT " + limit);
        return aiInteractionMapper.selectList(wrapper);
    }

    @Override
    public void deleteBySessionId(String sessionId) {
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId);
        aiInteractionMapper.delete(wrapper);
        log.info("删除会话历史: sessionId={}", sessionId);
    }

    @Override
    public Long countBySessionId(String sessionId) {
        LambdaQueryWrapper<AiInteraction> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(AiInteraction::getSessionId, sessionId)
                .eq(AiInteraction::getInteractionType, TYPE_CHAT);
        return aiInteractionMapper.selectCount(wrapper);
    }
}
