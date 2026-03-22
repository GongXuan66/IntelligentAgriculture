package com.agriculture.entity;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;
import java.time.LocalDate;
import java.time.LocalDateTime;

/**
 * 作物种植信息实体
 */
@Data
@TableName("crop_planting")
public class CropPlanting {

    @TableId(type = IdType.AUTO)
    private Long id;

    @TableField("point_id")
    private Long pointId;

    @TableField("crop_code")
    private String cropCode;

    @TableField("crop_name")
    private String cropName;

    @TableField("variety")
    private String variety;

    @TableField("planting_date")
    private LocalDate plantingDate;

    @TableField("expected_harvest_date")
    private LocalDate expectedHarvestDate;

    @TableField("current_stage")
    private String currentStage;

    @TableField("current_stage_day")
    private Integer currentStageDay;

    @TableField("stage_updated_at")
    private LocalDate stageUpdatedAt;

    @TableField("status")
    private Integer status = 1;

    @TableField(value = "created_at", fill = FieldFill.INSERT)
    private LocalDateTime createdAt;

    @TableField(value = "updated_at", fill = FieldFill.INSERT_UPDATE)
    private LocalDateTime updatedAt;
}
