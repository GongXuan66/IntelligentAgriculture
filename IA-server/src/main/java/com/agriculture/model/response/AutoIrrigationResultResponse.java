package com.agriculture.model.response;

import com.agriculture.model.dto.IrrigationDTO;
import lombok.Data;

/**
 * 自动灌溉启动结果.
 */
@Data
public class AutoIrrigationResultResponse {
    private boolean started;
    private AutoIrrigationPlanResponse plan;
    private IrrigationDTO log;
}
