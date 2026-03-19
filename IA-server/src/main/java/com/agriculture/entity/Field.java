package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 地块实体
 */
@Data
@TableName("field")
public class Field {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("field_id")
    private String fieldId;

    @TableField("field_name")
    private String fieldName;

    @TableField("field_type")
    private String fieldType;

    @TableField("location")
    private String location;

    @TableField("area")
    private BigDecimal area;

    @TableField("crop_type")
    private String cropType;

    @TableField("description")
    private String description;

    @TableField("status")
    private Integer status = 1;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
