package com.agriculture.model.dto;

import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 报警DTO
 */
@Data
public class AlarmDTO {

    private Long id;
    private Long pointId;
    private String alarmType;
    private BigDecimal alarmValue;
    private BigDecimal threshold;
    private Integer status;
    private LocalDateTime createdAt;
    private LocalDateTime handledAt;

    @Data
    public static class HandleRequest {
        private String remark;
    }
}
