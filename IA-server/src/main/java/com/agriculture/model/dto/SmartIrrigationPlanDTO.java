package com.agriculture.model.dto;

import lombok.Data;
import java.math.BigDecimal;

/**
 * 智能灌溉计划DTO
 */
@Data
public class SmartIrrigationPlanDTO {

    /**
     * 是否需要灌溉
     */
    private Boolean shouldIrrigate;

    /**
     * 决策类型: predictive/adaptive/stage_based/standard
     */
    private String decisionType;

    /**
     * 建议用水量(升)
     */
    private BigDecimal waterAmountL;

    /**
     * 灌溉时长(秒)
     */
    private Integer durationSeconds;

    /**
     * 目标湿度(%)
     */
    private BigDecimal targetMoisture;

    /**
     * 当前湿度(%)
     */
    private BigDecimal currentMoisture;

    /**
     * 预测湿度(%)
     */
    private BigDecimal predictedMoisture;

    /**
     * 灌溉系数
     */
    private BigDecimal irrigationFactor;

    /**
     * 作物生长阶段
     */
    private String cropStage;

    /**
     * 决策理由
     */
    private String reason;

    /**
     * 决策置信度
     */
    private BigDecimal confidence;

    /**
     * 预测模式: standard/ewma/lstm
     */
    private String predictionMode;
}
