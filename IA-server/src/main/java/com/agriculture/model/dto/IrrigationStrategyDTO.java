package com.agriculture.model.dto;

import lombok.Data;
import java.math.BigDecimal;

/**
 * 灌溉策略DTO（基于作物生长阶段）
 */
@Data
public class IrrigationStrategyDTO {

    /**
     * 作物编码
     */
    private String cropCode;

    /**
     * 作物名称
     */
    private String cropName;

    /**
     * 当前生长阶段
     */
    private String currentStage;

    /**
     * 播种以来天数
     */
    private Integer daysSincePlanting;

    /**
     * 最低土壤湿度(%)
     */
    private BigDecimal minHumidity;

    /**
     * 最高土壤湿度(%)
     */
    private BigDecimal maxHumidity;

    /**
     * 最佳土壤湿度(%)
     */
    private BigDecimal optimalHumidity;

    /**
     * 灌溉系数
     */
    private BigDecimal irrigationFactor;

    /**
     * 灌溉频率建议
     */
    private String frequencyHint;

    /**
     * 需水特点
     */
    private String waterNeeds;

    /**
     * 特殊注意事项
     */
    private String specialNotes;

    /**
     * 是否有作物配置
     */
    private Boolean hasCropConfig = false;
}