package com.agriculture.service;

import com.agriculture.model.dto.EnvironmentDataDTO;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.concurrent.TimeUnit;

@Slf4j
@Service
@RequiredArgsConstructor
public class EnvironmentCacheService {

    private static final String CACHE_KEY_PREFIX = "env:current:";

    private final StringRedisTemplate stringRedisTemplate;
    private final ObjectMapper objectMapper;

    @Value("${cache.environment.local.max-size:1000}")
    private long localMaxSize;

    @Value("${cache.environment.local.ttl-seconds:30}")
    private long localTtlSeconds;

    @Value("${cache.environment.redis.ttl-seconds:120}")
    private long redisTtlSeconds;

    private Cache<Long, EnvironmentDataDTO> localCache;

    @jakarta.annotation.PostConstruct
    public void init() {
        localCache = Caffeine.newBuilder()
                .maximumSize(localMaxSize)
                .expireAfterWrite(localTtlSeconds, TimeUnit.SECONDS)
                .build();
    }

    public EnvironmentDataDTO get(Long pointId) {
        if (pointId == null) {
            return null;
        }

        EnvironmentDataDTO localValue = localCache.getIfPresent(pointId);
        if (localValue != null) {
            return localValue;
        }

        try {
            String redisValue = stringRedisTemplate.opsForValue().get(buildRedisKey(pointId));
            if (redisValue == null || redisValue.isBlank()) {
                return null;
            }

            EnvironmentDataDTO value = objectMapper.readValue(redisValue, EnvironmentDataDTO.class);
            localCache.put(pointId, value);
            return value;
        } catch (Exception e) {
            log.warn("读取环境缓存失败, pointId={}", pointId, e);
            return null;
        }
    }

    public void put(Long pointId, EnvironmentDataDTO dto) {
        if (pointId == null || dto == null) {
            return;
        }

        localCache.put(pointId, dto);

        try {
            String json = objectMapper.writeValueAsString(dto);
            stringRedisTemplate.opsForValue().set(
                    buildRedisKey(pointId),
                    json,
                    Duration.ofSeconds(redisTtlSeconds)
            );
        } catch (JsonProcessingException e) {
            log.warn("写入环境缓存失败, pointId={}", pointId, e);
        }
    }

    public void evict(Long pointId) {
        if (pointId == null) {
            return;
        }

        localCache.invalidate(pointId);
        try {
            stringRedisTemplate.delete(buildRedisKey(pointId));
        } catch (Exception e) {
            log.warn("删除环境缓存失败, pointId={}", pointId, e);
        }
    }

    private String buildRedisKey(Long pointId) {
        return CACHE_KEY_PREFIX + pointId;
    }
}
