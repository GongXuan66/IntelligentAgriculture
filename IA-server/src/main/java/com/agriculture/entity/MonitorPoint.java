package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 检测点实体
 */
@Data
@TableName("monitor_point")
public class MonitorPoint {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private String pointId;

    @TableField("point_name")
    private String pointName;

    @TableField("location")
    private String location;

    @TableField("crop_type")
    private String cropType;

    @TableField("status")
    private Integer status = 1;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}