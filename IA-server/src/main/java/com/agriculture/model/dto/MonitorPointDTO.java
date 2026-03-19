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
    private String pointId;
    private String pointName;
    private String location;
    private String cropType;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;

    @Data
    public static class CreateRequest {
        @NotBlank(message = "检测点ID不能为空")
        private String pointId;

        @NotBlank(message = "检测点名称不能为空")
        private String pointName;

        private String location;
        private String cropType;
    }

    @Data
    public static class UpdateRequest {
        private String pointName;
        private String location;
        private String cropType;
        private Integer status;
    }
}
