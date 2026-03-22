package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 灌溉记录实体
 */
@Data
@TableName("irrigation_log")
public class IrrigationLog {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    @TableField("water_amount")
    private BigDecimal waterAmount;

    @TableField("duration")
    private Integer duration;

    @TableField("mode")
    private Integer mode = 0;

    @TableField("decision_type")
    private String decisionType;

    @TableField("current_moisture")
    private BigDecimal currentMoisture;

    @TableField("predicted_moisture")
    private BigDecimal predictedMoisture;

    @TableField("prediction_hours")
    private Integer predictionHours;

    @TableField("crop_stage")
    private String cropStage;

    @TableField("irrigation_factor")
    private BigDecimal irrigationFactor;

    @TableField("confidence")
    private BigDecimal confidence;

    @TableField("soil_moisture_before")
    private BigDecimal soilMoistureBefore;

    @TableField("soil_moisture_after")
    private BigDecimal soilMoistureAfter;

    @TableField("temperature")
    private BigDecimal temperature;

    @TableField("humidity")
    private BigDecimal humidity;

    @TableField("trigger_reason")
    private String triggerReason;

    @TableField("start_time")
    private LocalDateTime startTime;

    @TableField("end_time")
    private LocalDateTime endTime;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}