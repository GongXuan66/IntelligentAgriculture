package com.agriculture.model.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 检测点DTO
 */
@Data
public class MonitorPointDTO {

    private Long id;
    private Long farmId;
    private String pointCode;
    private String pointName;
    private String location;
    private BigDecimal area;
    private String soilType;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    // 关联的农场名称（用于显示）
    private String farmName;

    @Data
    public static class CreateRequest {
        private Long farmId;

        private String pointCode;

        @NotBlank(message = "检测点名称不能为空")
        private String pointName;

        private String location;
        private BigDecimal area;
        private String soilType;
    }

    @Data
    public static class UpdateRequest {
        private Long farmId;
        private String pointCode;
        private String pointName;
        private String location;
        private BigDecimal area;
        private String soilType;
        private Integer status;
    }
}