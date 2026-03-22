package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDateTime;

/**
 * 作物类型实体
 */
@Data
@TableName("crop_type")
public class CropType {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("crop_code")
    private String cropCode;

    @TableField("crop_name")
    private String cropName;

    @TableField("category")
    private String category;

    @TableField("growth_cycle_days")
    private Integer growthCycleDays;

    @TableField("water_requirement")
    private String waterRequirement;

    @TableField("temperature_range")
    private String temperatureRange;

    @TableField("icon_url")
    private String iconUrl;

    @TableField("description")
    private String description;

    @TableField("is_active")
    private Integer isActive = 1;

    @TableField("sort_order")
    private Integer sortOrder = 0;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;
}
