package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 环境数据实体
 */
@Data
@TableName("sensor_data")
public class SensorData {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    @TableField("temperature")
    private BigDecimal temperature;

    @TableField("humidity")
    private BigDecimal humidity;

    @TableField("light")
    private BigDecimal light;

    @TableField("co2")
    private BigDecimal co2;

    @TableField("soil_moisture")
    private BigDecimal soilMoisture;

    @TableField("recorded_at")
    private LocalDateTime recordedAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}