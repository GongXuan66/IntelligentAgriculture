package com.agriculture.service;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.entity.IrrigationThresholdConfig;

import java.math.BigDecimal;
import java.util.Map;

public interface IrrigationLearningService {

    void learn(IrrigationLog irrigationLog);

    IrrigationThresholdConfig getThresholdConfig(Long pointId);

    BigDecimal getLearnedMoistureGain(Long pointId);

    Map<String, BigDecimal> getAllLearnedParams(Long pointId);

    Map<String, Object> getLearningProgress(Long pointId);

    BigDecimal adjustWaterAmount(Long pointId, BigDecimal baseAmount);
}
