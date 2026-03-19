package com.agriculture.model.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 环境数据DTO
 */
@Data
public class EnvironmentDataDTO {

    private Long id;
    private Long pointId;
    private BigDecimal temperature;
    private BigDecimal humidity;
    private BigDecimal light;
    private BigDecimal co2;
    private BigDecimal soilMoisture;
    private LocalDateTime recordedAt;
    private LocalDateTime createdAt;
}
