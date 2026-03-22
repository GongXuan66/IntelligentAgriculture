package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 农场实体
 */
@Data
@TableName("farm")
public class Farm {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("user_id")
    private Long userId;

    @TableField("farm_name")
    private String farmName;

    @TableField("farm_code")
    private String farmCode;

    @TableField("location")
    private String location;

    @TableField("province")
    private String province;

    @TableField("city")
    private String city;

    @TableField("area")
    private BigDecimal area;

    @TableField("description")
    private String description;

    @TableField("status")
    private Integer status = 1;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
