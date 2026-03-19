package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 报警记录实体
 */
@Data
@TableName("alarm")
public class Alarm {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    @TableField("alarm_type")
    private String alarmType;

    @TableField("alarm_value")
    private BigDecimal alarmValue;

    @TableField("threshold")
    private BigDecimal threshold;

    @TableField("status")
    private Integer status = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField("handled_at")
    private LocalDateTime handledAt;
}