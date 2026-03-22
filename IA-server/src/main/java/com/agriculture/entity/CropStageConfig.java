package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 作物生长阶段配置实体（知识库）
 */
@Data
@TableName("crop_stage_config")
public class CropStageConfig {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("crop_code")
    private String cropCode;

    @TableField("stage_code")
    private String stageCode;

    @TableField("stage_name")
    private String stageName;

    @TableField("stage_order")
    private Integer stageOrder;

    @TableField("start_day")
    private Integer startDay;

    @TableField("end_day")
    private Integer endDay;

    @TableField("min_humidity")
    private BigDecimal minHumidity;

    @TableField("max_humidity")
    private BigDecimal maxHumidity;

    @TableField("optimal_humidity")
    private BigDecimal optimalHumidity;

    @TableField("irrigation_factor")
    private BigDecimal irrigationFactor;

    @TableField("frequency_hint")
    private String frequencyHint;

    @TableField("water_needs")
    private String waterNeeds;

    @TableField("special_notes")
    private String specialNotes;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}