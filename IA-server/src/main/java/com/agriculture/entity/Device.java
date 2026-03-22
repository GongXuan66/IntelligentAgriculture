package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 设备实体
 */
@Data
@TableName("device")
public class Device {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    @TableField("device_code")
    private String deviceCode;

    @TableField("device_name")
    private String deviceName;

    @TableField("device_type")
    private String deviceType;

    @TableField("device_model")
    private String deviceModel;

    @TableField("manufacturer")
    private String manufacturer;

    @TableField("status")
    private Integer status = 0;

    @TableField("last_heartbeat")
    private LocalDateTime lastHeartbeat;

    @TableField("installed_at")
    private LocalDateTime installedAt;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
