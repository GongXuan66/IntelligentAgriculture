package com.agriculture.model.dto;

import jakarta.validation.constraints.NotNull;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 灌溉DTO
 */
@Data
public class IrrigationDTO {

    private Long id;
    private Long pointId;
    private BigDecimal waterAmount;
    private Integer duration;
    private Integer mode;
    private LocalDateTime startTime;
    private LocalDateTime endTime;
    private LocalDateTime createdAt;

    @Data
    public static class StartRequest {
        @NotNull(message = "检测点ID不能为空")
        private Long pointId;

        @NotNull(message = "灌溉时长不能为空")
        private Integer duration;

        private Integer mode = 1;  // 默认手动模式
    }

    @Data
    public static class StopRequest {
        @NotNull(message = "灌溉记录ID不能为空")
        private Long logId;
    }
}
