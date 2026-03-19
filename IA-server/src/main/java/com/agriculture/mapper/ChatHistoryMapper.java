package com.agriculture.mapper;

import com.agriculture.entity.ChatHistory;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface ChatHistoryMapper extends BaseMapper<ChatHistory> {

    /**
     * 按会话ID查询历史，按时间升序
     */
    @Select("SELECT * FROM chat_history WHERE session_id = #{sessionId} ORDER BY created_at ASC")
    List<ChatHistory> findBySessionIdOrderByCreatedAtAsc(@Param("sessionId") String sessionId);

    /**
     * 按会话ID查询最近N条历史
     */
    @Select("SELECT * FROM chat_history WHERE session_id = #{sessionId} ORDER BY created_at DESC LIMIT #{limit}")
    List<ChatHistory> findRecentBySessionId(@Param("sessionId") String sessionId, @Param("limit") int limit);

    /**
     * 统计会话的消息数量
     */
    @Select("SELECT COUNT(*) FROM chat_history WHERE session_id = #{sessionId}")
    Long countBySessionId(@Param("sessionId") String sessionId);
}
