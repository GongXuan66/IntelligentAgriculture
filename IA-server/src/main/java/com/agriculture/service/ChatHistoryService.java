package com.agriculture.service;

import com.agriculture.entity.AiInteraction;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;

import java.util.List;

public interface ChatHistoryService {

    void saveUserMessage(String sessionId, String content);

    void saveAssistantMessage(String sessionId, String content);

    void saveMessageAsync(String sessionId, String role, String content);

    List<AiInteraction> getHistoryBySessionId(String sessionId);

    Page<AiInteraction> getHistoryPaged(String sessionId, int pageNum, int pageSize);

    List<AiInteraction> getRecentHistory(String sessionId, int limit);

    void deleteBySessionId(String sessionId);

    Long countBySessionId(String sessionId);
}
