package com.agriculture.model.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 农场DTO
 */
@Data
public class FarmDTO {

    private Long id;
    private Long userId;
    private String farmName;
    private String farmCode;
    private String location;
    private String province;
    private String city;
    private BigDecimal area;
    private String description;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    
    // 关联的检测点数量
    private Integer pointCount;

    @Data
    public static class CreateRequest {
        private Long userId;

        @NotBlank(message = "农场名称不能为空")
        private String farmName;

        private String farmCode;
        private String location;
        private String province;
        private String city;
        private BigDecimal area;
        private String description;
    }

    @Data
    public static class UpdateRequest {
        private String farmName;
        private String location;
        private String province;
        private String city;
        private BigDecimal area;
        private String description;
        private Integer status;
    }
    
    /**
     * 农场详情（含检测点列表）
     */
    @Data
    public static class DetailResponse {
        private FarmDTO farm;
        private List<MonitorPointDTO> points;
    }
}
