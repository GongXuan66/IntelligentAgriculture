package com.agriculture.model.request;

import com.agriculture.model.dto.EnvironmentDataDTO;
import lombok.Data;

/**
 * 请求在一次调用中计算并启动自动灌溉.
 */
@Data
public class AutoIrrigationRequest {
    private Long pointId;
    private EnvironmentDataDTO envData;
    private IrrigationPlanConfig config;
}
