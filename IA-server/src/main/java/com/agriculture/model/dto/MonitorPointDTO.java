package com.agriculture.model.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 检测点DTO
 */
@Data
public class MonitorPointDTO {

    private Long id;
    private Long fieldId;
    private String pointId;
    private String pointName;
    private String location;
    private String cropType;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    // 关联的地块名称（用于显示）
    private String fieldName;

    @Data
    public static class CreateRequest {
        private Long fieldId;

        @NotBlank(message = "检测点ID不能为空")
        private String pointId;

        @NotBlank(message = "检测点名称不能为空")
        private String pointName;

        private String location;
        private String cropType;
    }

    @Data
    public static class UpdateRequest {
        private Long fieldId;
        private String pointName;
        private String location;
        private String cropType;
        private Integer status;
    }
}
