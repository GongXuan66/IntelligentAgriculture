package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * AI交互记录实体（合并对话、推荐、报告）
 */
@Data
@TableName("ai_interaction")
public class AiInteraction {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("point_id")
    private Long pointId;

    /**
     * 交互类型: chat/recommendation/report
     */
    @TableField("interaction_type")
    private String interactionType;

    /**
     * 会话ID（对话用）
     */
    @TableField("session_id")
    private String sessionId;

    /**
     * 角色: user/assistant/system（对话用）
     */
    @TableField("role")
    private String role;

    /**
     * 标题（推荐/报告用）
     */
    @TableField("title")
    private String title;

    /**
     * 内容
     */
    @TableField("content")
    private String content;

    /**
     * 报告类型: daily/weekly/monthly
     */
    @TableField("report_type")
    private String reportType;

    /**
     * 报告日期
     */
    @TableField("report_date")
    private LocalDate reportDate;

    /**
     * 推荐类型: irrigation/planting/pest/alert
     */
    @TableField("recommendation_type")
    private String recommendationType;

    /**
     * 置信度
     */
    @TableField("confidence")
    private BigDecimal confidence;

    /**
     * 状态: 0待处理 1已采纳 2已忽略
     */
    @TableField("status")
    private Integer status = 0;

    /**
     * 用户反馈
     */
    @TableField("feedback")
    private String feedback;

    /**
     * Token数量
     */
    @TableField("token_count")
    private Integer tokenCount;

    /**
     * 使用的模型
     */
    @TableField("model")
    private String model;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
