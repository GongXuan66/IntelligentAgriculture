package com.agriculture.model.response;

import lombok.Data;
import java.math.BigDecimal;

/**
 * 后端计算的自动灌溉计划.
 */
@Data
public class AutoIrrigationPlanResponse {
    private boolean shouldIrrigate;
    private BigDecimal waterAmountL;
    private Integer durationSeconds;
    private BigDecimal targetMoisture;
    private BigDecimal moistureGap;
    private BigDecimal riskFactor;
    private String reason;
}
