package com.agriculture.ai.client;

import com.agriculture.common.exception.BusinessException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class IaAiClient {

    @Value("${iaai.base-url:http://localhost:8000}")
    private String baseUrl;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    public ChatSyncResult chatSync(String sessionId, String message) {
        try {
            String url = UriComponentsBuilder.fromHttpUrl(baseUrl)
                    .pathSegment("api", "chat", "sync")
                    .toUriString();

            Map<String, Object> request = new HashMap<>();
            request.put("session_id", sessionId);
            request.put("message", message);

            String response = restTemplate.postForObject(url, request, String.class);
            JsonNode root = objectMapper.readTree(response);
            String responseSessionId = root.path("session_id").asText(sessionId);
            String answer = root.path("answer").asText();
            if (answer == null || answer.isBlank()) {
                throw new BusinessException(502, "IA-AI 返回空响应");
            }
            return new ChatSyncResult(responseSessionId, answer);
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("IA-AI 同步对话失败", e);
            throw new BusinessException(502, "IA-AI 同步对话失败: " + e.getMessage());
        }
    }

    public void clearSession(String sessionId) {
        try {
            String url = UriComponentsBuilder.fromHttpUrl(baseUrl)
                    .pathSegment("api", "chat", "clear")
                    .toUriString();

            Map<String, Object> request = new HashMap<>();
            request.put("session_id", sessionId);
            restTemplate.postForObject(url, request, String.class);
        } catch (Exception e) {
            log.error("IA-AI 清除会话失败", e);
            throw new BusinessException(502, "IA-AI 清除会话失败: " + e.getMessage());
        }
    }

    public record ChatSyncResult(String sessionId, String reply) {}
}
