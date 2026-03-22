package com.agriculture.model.dto;

import lombok.Data;
import java.math.BigDecimal;

/**
 * 湿度预测结果DTO
 */
@Data
public class MoisturePredictionDTO {

    /**
     * 当前湿度
     */
    private BigDecimal currentMoisture;

    /**
     * 预测2小时后湿度
     */
    private BigDecimal predict2h;

    /**
     * 预测4小时后湿度
     */
    private BigDecimal predict4h;

    /**
     * 预测6小时后湿度
     */
    private BigDecimal predict6h;

    /**
     * 趋势: rising/falling/stable
     */
    private String trend;

    /**
     * 是否需要预防性灌溉
     */
    private Boolean needPreIrrigation;

    /**
     * 决策理由
     */
    private String reason;

    /**
     * 预测置信度
     */
    private BigDecimal confidence;
}
