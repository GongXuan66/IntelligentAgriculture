package com.agriculture.model.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 地块DTO
 */
@Data
public class FieldDTO {

    private Long id;
    private String fieldId;
    private String fieldName;
    private String fieldType;
    private String location;
    private BigDecimal area;
    private String cropType;
    private String description;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    // 关联的检测点数量
    private Integer pointCount;

    @Data
    public static class CreateRequest {
        @NotBlank(message = "地块编号不能为空")
        private String fieldId;

        @NotBlank(message = "地块名称不能为空")
        private String fieldName;

        private String fieldType;
        private String location;
        private BigDecimal area;
        private String cropType;
        private String description;
    }

    @Data
    public static class UpdateRequest {
        private String fieldName;
        private String fieldType;
        private String location;
        private BigDecimal area;
        private String cropType;
        private String description;
        private Integer status;
    }
    
    /**
     * 地块详情（含检测点列表）
     */
    @Data
    public static class DetailResponse {
        private FieldDTO field;
        private List<MonitorPointDTO> points;
    }
}
