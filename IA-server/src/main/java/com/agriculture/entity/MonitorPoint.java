package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 检测点/地块实体
 */
@Data
@TableName("monitor_point")
public class MonitorPoint {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("farm_id")
    private Long farmId;

    @TableField("point_code")
    private String pointCode;

    @TableField("point_name")
    private String pointName;

    @TableField("location")
    private String location;

    @TableField("area")
    private BigDecimal area;

    @TableField("soil_type")
    private String soilType;

    @TableField("status")
    private Integer status = 1;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
