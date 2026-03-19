package com.agriculture.model.request;

import com.agriculture.model.dto.EnvironmentDataDTO;
import lombok.Data;

/**
 * Request for a backend-side irrigation plan.
 */
@Data
public class IrrigationPlanRequest {
    private Long pointId;
    private EnvironmentDataDTO envData;
    private IrrigationPlanConfig config;
}
