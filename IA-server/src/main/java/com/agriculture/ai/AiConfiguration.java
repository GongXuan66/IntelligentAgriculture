package com.agriculture.ai;

import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.memory.chat.ChatMemoryProvider;
import dev.langchain4j.memory.chat.MessageWindowChatMemory;
import dev.langchain4j.model.chat.listener.ChatModelErrorContext;
import dev.langchain4j.model.chat.listener.ChatModelListener;
import dev.langchain4j.model.chat.listener.ChatModelRequestContext;
import dev.langchain4j.model.chat.listener.ChatModelResponseContext;
import dev.langchain4j.store.memory.chat.ChatMemoryStore;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.RedisTemplate;

import java.time.Duration;
import java.util.List;

import static dev.langchain4j.data.message.ChatMessageDeserializer.messagesFromJson;
import static dev.langchain4j.data.message.ChatMessageSerializer.messagesToJson;

@Slf4j
@Configuration
public class AiConfiguration {

    @Bean
    ChatModelListener chatModelListener() {
        return new ChatModelListener() {
            private static final Logger log = LoggerFactory.getLogger(ChatModelListener.class);
            @Override
            public void onRequest(ChatModelRequestContext requestContext) {
                log.info("onRequest(): {}", requestContext.chatRequest());
            }
            @Override
            public void onResponse(ChatModelResponseContext responseContext) {
                log.info("onResponse(): {}", responseContext.chatResponse());
            }

            @Override
            public void onError(ChatModelErrorContext errorContext) {
                log.info("onError(): {}", errorContext.error().getMessage());
            }
        };
    }

    /**
     * Redis 存储实现
     * 会话记忆持久化到 Redis，支持分布式部署
     */
    @Bean
    ChatMemoryStore chatMemoryStore(RedisTemplate<String, String> redisTemplate) {
        return new RedisChatMemoryStore(redisTemplate);
    }

    /**
     * 记忆提供者：按会话ID创建独立的滑动窗口记忆
     * 每个会话保留最近 10 条消息
     */
    @Bean
    ChatMemoryProvider chatMemoryProvider(ChatMemoryStore chatMemoryStore) {
        return memoryId -> MessageWindowChatMemory.builder()
                .id(memoryId)
                .maxMessages(10)
                .chatMemoryStore(chatMemoryStore)
                .build();
    }

    /**
     * 基于 Redis 的对话记忆存储
     */
    @RequiredArgsConstructor
    static class RedisChatMemoryStore implements ChatMemoryStore {

        private static final String KEY_PREFIX = "ai:chat:memory:";
        private static final Duration TTL = Duration.ofHours(24);

        private final RedisTemplate<String, String> redisTemplate;

        @Override
        public List<ChatMessage> getMessages(Object memoryId) {
            String json = redisTemplate.opsForValue().get(key(memoryId));
            if (json == null || json.isEmpty()) {
                return List.of();
            }
            return messagesFromJson(json);
        }

        @Override
        public void updateMessages(Object memoryId, List<ChatMessage> messages) {
            String json = messagesToJson(messages);
            redisTemplate.opsForValue().set(key(memoryId), json, TTL);
        }

        @Override
        public void deleteMessages(Object memoryId) {
            redisTemplate.delete(key(memoryId));
        }

        private String key(Object memoryId) {
            return KEY_PREFIX + memoryId;
        }
    }
}
