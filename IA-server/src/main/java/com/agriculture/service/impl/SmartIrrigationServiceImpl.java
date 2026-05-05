package com.agriculture.service.impl;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.mapper.IrrigationLogMapper;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import com.agriculture.model.dto.MoisturePredictionDTO;
import com.agriculture.model.dto.SmartIrrigationPlanDTO;
import com.agriculture.model.request.IrrigationPlanConfig;
import com.agriculture.service.CropStageService;
import com.agriculture.service.IrrigationLearningService;
import com.agriculture.service.MoisturePredictor;
import com.agriculture.service.SmartIrrigationService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class SmartIrrigationServiceImpl implements SmartIrrigationService {

    private final MoisturePredictor moisturePredictor;
    private final IrrigationLearningService learningService;
    private final CropStageService cropStageService;
    private final IrrigationLogMapper irrigationLogMapper;

    private static final BigDecimal WATER_PER_SECOND = new BigDecimal("0.5");
    private static final BigDecimal DEFAULT_MOISTURE_GAIN = new BigDecimal("1.6667");
    private static final int MIN_DURATION_SEC = 10;
    private static final int MAX_DURATION_SEC = 180;

    @Override
    public SmartIrrigationPlanDTO buildSmartPlan(Long pointId, EnvironmentDataDTO envData,
                                                   IrrigationPlanConfig config) {
        SmartIrrigationPlanDTO plan = new SmartIrrigationPlanDTO();

        if (envData == null || envData.getSoilMoisture() == null) {
            plan.setShouldIrrigate(false);
            plan.setDecisionType("standard");
            plan.setReason("缺少环境数据");
            return plan;
        }

        int threshold = getThreshold(config);
        BigDecimal soilMoisture = envData.getSoilMoisture();

        plan.setCurrentMoisture(soilMoisture);
        plan.setPredictionMode("ewma");

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(pointId);
        plan.setCropStage(strategy.getCurrentStage());
        plan.setIrrigationFactor(strategy.getIrrigationFactor());

        MoisturePredictionDTO prediction = moisturePredictor.analyze(pointId, threshold);
        plan.setPredictedMoisture(prediction.getPredict2h());
        plan.setConfidence(prediction.getConfidence());

        if (soilMoisture.compareTo(BigDecimal.valueOf(threshold)) < 0) {
            plan.setShouldIrrigate(true);
            plan.setDecisionType("adaptive");
            plan.setReason("当前湿度低于阈值，需要立即灌溉");
        } else if (Boolean.TRUE.equals(prediction.getNeedPreIrrigation())) {
            plan.setShouldIrrigate(true);
            plan.setDecisionType("predictive");
            plan.setReason(prediction.getReason());
        } else {
            plan.setShouldIrrigate(false);
            plan.setDecisionType(strategy.getHasCropConfig() ? "stage_based" : "standard");
            plan.setReason(prediction.getReason());
            return plan;
        }

        BigDecimal targetMoisture = calculateTargetMoisture(threshold, strategy);
        BigDecimal moistureGap = targetMoisture.subtract(soilMoisture).max(BigDecimal.ZERO);

        BigDecimal baseWaterAmount = moistureGap.divide(DEFAULT_MOISTURE_GAIN, 4, RoundingMode.HALF_UP);

        BigDecimal riskFactor = calculateRiskFactor(envData);
        BigDecimal waterAmount = baseWaterAmount.multiply(riskFactor);

        waterAmount = cropStageService.adjustWaterByStage(waterAmount, strategy, soilMoisture);
        waterAmount = learningService.adjustWaterAmount(pointId, waterAmount);
        waterAmount = clamp(waterAmount, new BigDecimal("0.5"), new BigDecimal("45"));

        int durationSeconds = waterAmount.divide(WATER_PER_SECOND, 0, RoundingMode.HALF_UP).intValue();
        durationSeconds = Math.max(MIN_DURATION_SEC, Math.min(MAX_DURATION_SEC, durationSeconds));

        plan.setWaterAmountL(waterAmount.setScale(1, RoundingMode.HALF_UP));
        plan.setDurationSeconds(durationSeconds);
        plan.setTargetMoisture(targetMoisture.setScale(1, RoundingMode.HALF_UP));

        log.info("智能灌溉计划: pointId={}, shouldIrrigate={}, decisionType={}, water={}, duration={}",
                pointId, plan.getShouldIrrigate(), plan.getDecisionType(),
                plan.getWaterAmountL(), plan.getDurationSeconds());

        return plan;
    }

    @Override
    @Transactional
    public IrrigationLog executeSmartIrrigation(Long pointId, SmartIrrigationPlanDTO plan,
                                                 EnvironmentDataDTO envData) {
        IrrigationLog irrigationLog = new IrrigationLog();
        irrigationLog.setPointId(pointId);
        irrigationLog.setDuration(plan.getDurationSeconds());
        irrigationLog.setMode(0);
        irrigationLog.setStartTime(LocalDateTime.now());

        irrigationLog.setDecisionType(plan.getDecisionType());
        irrigationLog.setCurrentMoisture(plan.getCurrentMoisture());
        irrigationLog.setPredictedMoisture(plan.getPredictedMoisture());
        irrigationLog.setCropStage(plan.getCropStage());
        irrigationLog.setIrrigationFactor(plan.getIrrigationFactor());
        irrigationLog.setConfidence(plan.getConfidence());
        irrigationLog.setTriggerReason(plan.getReason());

        BigDecimal waterAmount = WATER_PER_SECOND.multiply(BigDecimal.valueOf(plan.getDurationSeconds()));
        irrigationLog.setWaterAmount(waterAmount);

        if (envData != null) {
            irrigationLog.setSoilMoistureBefore(envData.getSoilMoisture());
            irrigationLog.setTemperature(envData.getTemperature());
            irrigationLog.setHumidity(envData.getHumidity());
        }

        irrigationLogMapper.insert(irrigationLog);
        log.info("智能灌溉已启动: logId={}, pointId={}, duration={}s, decisionType={}",
                irrigationLog.getId(), pointId, plan.getDurationSeconds(), plan.getDecisionType());

        return irrigationLog;
    }

    @Override
    @Transactional
    public void onIrrigationComplete(Long logId, BigDecimal soilMoistureAfter) {
        IrrigationLog irrigationLog = irrigationLogMapper.selectById(logId);
        if (irrigationLog == null) {
            return;
        }

        irrigationLog.setEndTime(LocalDateTime.now());
        irrigationLog.setSoilMoistureAfter(soilMoistureAfter);

        irrigationLogMapper.updateById(irrigationLog);
        learningService.learn(irrigationLog);

        BigDecimal actualGain = null;
        if (irrigationLog.getSoilMoistureBefore() != null && soilMoistureAfter != null) {
            actualGain = soilMoistureAfter.subtract(irrigationLog.getSoilMoistureBefore());
        }
        log.info("灌溉完成并学习: logId={}, actualGain={}", logId, actualGain);
    }

    @Override
    public SmartIrrigationStats getStats(Long pointId) {
        SmartIrrigationStats stats = new SmartIrrigationStats();

        stats.setLearningProgress(learningService.getLearningProgress(pointId));
        stats.setCropStrategy(cropStageService.getStrategy(pointId));

        LambdaQueryWrapper<IrrigationLog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(IrrigationLog::getPointId, pointId)
               .orderByDesc(IrrigationLog::getStartTime)
               .last("LIMIT 10");
        stats.setRecentIrrigations(irrigationLogMapper.selectList(wrapper));

        return stats;
    }

    private int getThreshold(IrrigationPlanConfig config) {
        if (config != null && config.getMoistureThreshold() != null) {
            return Math.max(20, Math.min(70, config.getMoistureThreshold()));
        }
        return 40;
    }

    private BigDecimal calculateTargetMoisture(int threshold, IrrigationStrategyDTO strategy) {
        if (strategy.getOptimalHumidity() != null) {
            return strategy.getOptimalHumidity();
        }

        BigDecimal target = BigDecimal.valueOf(threshold + 12);
        if (strategy.getMaxHumidity() != null) {
            target = target.min(strategy.getMaxHumidity());
        }
        return target.min(new BigDecimal("75"));
    }

    private BigDecimal calculateRiskFactor(EnvironmentDataDTO envData) {
        BigDecimal factor = BigDecimal.ONE;

        if (envData.getTemperature() != null) {
            BigDecimal temp = envData.getTemperature();
            if (temp.compareTo(new BigDecimal("35")) > 0) {
                factor = factor.add(new BigDecimal("0.2"));
            } else if (temp.compareTo(new BigDecimal("30")) > 0) {
                factor = factor.add(new BigDecimal("0.1"));
            } else if (temp.compareTo(new BigDecimal("15")) < 0) {
                factor = factor.subtract(new BigDecimal("0.08"));
            }
        }

        if (envData.getHumidity() != null) {
            BigDecimal humidity = envData.getHumidity();
            if (humidity.compareTo(new BigDecimal("40")) < 0) {
                factor = factor.add(new BigDecimal("0.1"));
            } else if (humidity.compareTo(new BigDecimal("75")) > 0) {
                factor = factor.subtract(new BigDecimal("0.08"));
            }
        }

        if (envData.getLight() != null) {
            BigDecimal light = envData.getLight();
            if (light.compareTo(new BigDecimal("30000")) > 0) {
                factor = factor.add(new BigDecimal("0.15"));
            } else if (light.compareTo(new BigDecimal("15000")) > 0) {
                factor = factor.add(new BigDecimal("0.08"));
            }
        }

        return clamp(factor, new BigDecimal("0.75"), new BigDecimal("1.45"));
    }

    private BigDecimal clamp(BigDecimal value, BigDecimal min, BigDecimal max) {
        if (value.compareTo(min) < 0) return min;
        if (value.compareTo(max) > 0) return max;
        return value;
    }
}
