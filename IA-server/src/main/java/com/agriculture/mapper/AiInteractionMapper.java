package com.agriculture.mapper;

import com.agriculture.entity.AiInteraction;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

/**
 * AI交互记录 Mapper 接口
 */
@Mapper
public interface AiInteractionMapper extends BaseMapper<AiInteraction> {

    /**
     * 根据会话ID查询对话记录
     */
    @Select("SELECT * FROM ai_interaction WHERE session_id = #{sessionId} ORDER BY created_at")
    List<AiInteraction> findBySessionId(@Param("sessionId") String sessionId);

    /**
     * 查询用户的对话历史
     */
    @Select("SELECT * FROM ai_interaction WHERE user_id = #{userId} AND interaction_type = 'chat' ORDER BY created_at DESC LIMIT #{limit}")
    List<AiInteraction> findRecentChats(@Param("userId") Long userId, @Param("limit") int limit);

    /**
     * 查询用户的推荐列表
     */
    @Select("SELECT * FROM ai_interaction WHERE user_id = #{userId} AND interaction_type = 'recommendation' ORDER BY created_at DESC")
    List<AiInteraction> findRecommendationsByUserId(@Param("userId") Long userId);

    /**
     * 查询用户的报告列表
     */
    @Select("SELECT * FROM ai_interaction WHERE user_id = #{userId} AND interaction_type = 'report' ORDER BY created_at DESC")
    List<AiInteraction> findReportsByUserId(@Param("userId") Long userId);
}
