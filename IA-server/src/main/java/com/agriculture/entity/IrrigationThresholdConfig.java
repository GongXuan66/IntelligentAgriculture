package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 灌溉阈值配置实体
 */
@Data
@TableName("irrigation_threshold_config")
public class IrrigationThresholdConfig {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    // 阈值配置
    @TableField("moisture_threshold")
    private Integer moistureThreshold = 40;

    @TableField("max_single_irrigation")
    private Integer maxSingleIrrigation = 180;

    @TableField("min_irrigation_interval")
    private Integer minIrrigationInterval = 30;

    // 功能开关
    @TableField("enable_predictive")
    private Integer enablePredictive = 1;

    @TableField("enable_auto_control")
    private Integer enableAutoControl = 1;

    @TableField("prediction_mode")
    private String predictionMode = "ewma";

    // 学习参数
    @TableField("learned_moisture_gain")
    private BigDecimal learnedMoistureGain;

    @TableField("learning_sample_count")
    private Integer learningSampleCount = 0;

    @TableField("learning_confidence")
    private BigDecimal learningConfidence;

    @TableField("last_learning_at")
    private LocalDateTime lastLearningAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
