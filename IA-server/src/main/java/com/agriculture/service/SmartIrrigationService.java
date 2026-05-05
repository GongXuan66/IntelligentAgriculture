package com.agriculture.service;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import com.agriculture.model.dto.SmartIrrigationPlanDTO;
import com.agriculture.model.request.IrrigationPlanConfig;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public interface SmartIrrigationService {

    SmartIrrigationPlanDTO buildSmartPlan(Long pointId, EnvironmentDataDTO envData, IrrigationPlanConfig config);

    IrrigationLog executeSmartIrrigation(Long pointId, SmartIrrigationPlanDTO plan, EnvironmentDataDTO envData);

    void onIrrigationComplete(Long logId, BigDecimal soilMoistureAfter);

    SmartIrrigationStats getStats(Long pointId);

    @lombok.Data
    class SmartIrrigationStats {
        private Map<String, Object> learningProgress;
        private IrrigationStrategyDTO cropStrategy;
        private List<IrrigationLog> recentIrrigations;
    }
}
