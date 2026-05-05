package com.agriculture.service.impl;

import com.agriculture.entity.IrrigationThresholdConfig;
import com.agriculture.entity.IrrigationLog;
import com.agriculture.mapper.IrrigationThresholdConfigMapper;
import com.agriculture.service.IrrigationLearningService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@Slf4j
@Service
@RequiredArgsConstructor
public class IrrigationLearningServiceImpl implements IrrigationLearningService {

    private final IrrigationThresholdConfigMapper configMapper;

    private static final BigDecimal DEFAULT_MOISTURE_GAIN = new BigDecimal("1.5000");
    private static final BigDecimal DEFAULT_EVAPORATION_RATE = new BigDecimal("0.5");
    private static final BigDecimal DEFAULT_TEMP_FACTOR = BigDecimal.ONE;

    private static final double MAX_LEARNING_RATE = 0.3;
    private static final double MIN_LEARNING_RATE = 0.05;

    @Override
    @Transactional
    public void learn(IrrigationLog irrigationLog) {
        if (irrigationLog.getSoilMoistureAfter() == null || irrigationLog.getSoilMoistureBefore() == null) {
            log.debug("灌溉日志缺少湿度数据，跳过学习");
            return;
        }

        if (irrigationLog.getWaterAmount() == null || irrigationLog.getWaterAmount().compareTo(BigDecimal.ZERO) <= 0) {
            log.debug("灌溉日志缺少用水量数据，跳过学习");
            return;
        }

        BigDecimal actualGain = irrigationLog.getSoilMoistureAfter().subtract(irrigationLog.getSoilMoistureBefore());
        if (actualGain.compareTo(BigDecimal.ZERO) <= 0) {
            log.warn("灌溉后湿度未提升，可能存在数据异常");
            return;
        }

        BigDecimal actualGainPerLiter = actualGain.divide(irrigationLog.getWaterAmount(), 4, RoundingMode.HALF_UP);

        updateLearnedMoistureGain(irrigationLog.getPointId(), actualGainPerLiter);

        log.info("学习完成: pointId={}, 实际每升提升湿度={}", irrigationLog.getPointId(), actualGainPerLiter);
    }

    @Override
    public IrrigationThresholdConfig getThresholdConfig(Long pointId) {
        LambdaQueryWrapper<IrrigationThresholdConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(IrrigationThresholdConfig::getPointId, pointId);
        IrrigationThresholdConfig config = configMapper.selectOne(wrapper);

        if (config == null) {
            config = createDefaultConfig(pointId);
        }

        return config;
    }

    @Override
    public BigDecimal getLearnedMoistureGain(Long pointId) {
        IrrigationThresholdConfig config = getThresholdConfig(pointId);
        if (config.getLearnedMoistureGain() != null
                && config.getLearningConfidence() != null
                && config.getLearningConfidence().compareTo(new BigDecimal("0.5")) >= 0) {
            return config.getLearnedMoistureGain();
        }
        return DEFAULT_MOISTURE_GAIN;
    }

    @Override
    public Map<String, BigDecimal> getAllLearnedParams(Long pointId) {
        Map<String, BigDecimal> params = new HashMap<>();
        params.put("MOISTURE_GAIN_PER_LITER", DEFAULT_MOISTURE_GAIN);
        params.put("EVAPORATION_RATE", DEFAULT_EVAPORATION_RATE);
        params.put("TEMP_FACTOR", DEFAULT_TEMP_FACTOR);

        IrrigationThresholdConfig config = getThresholdConfig(pointId);
        if (config != null && config.getLearnedMoistureGain() != null
                && config.getLearningConfidence() != null
                && config.getLearningConfidence().compareTo(new BigDecimal("0.5")) >= 0) {
            params.put("MOISTURE_GAIN_PER_LITER", config.getLearnedMoistureGain());
        }

        return params;
    }

    @Override
    public Map<String, Object> getLearningProgress(Long pointId) {
        Map<String, Object> progress = new HashMap<>();
        IrrigationThresholdConfig config = getThresholdConfig(pointId);

        Map<String, Object> moistureGainInfo = new HashMap<>();
        moistureGainInfo.put("value", config.getLearnedMoistureGain() != null ? config.getLearnedMoistureGain() : DEFAULT_MOISTURE_GAIN);
        moistureGainInfo.put("confidence", config.getLearningConfidence() != null ? config.getLearningConfidence() : new BigDecimal("0.00"));
        moistureGainInfo.put("sampleCount", config.getLearningSampleCount() != null ? config.getLearningSampleCount() : 0);
        progress.put("MOISTURE_GAIN_PER_LITER", moistureGainInfo);

        return progress;
    }

    @Override
    public BigDecimal adjustWaterAmount(Long pointId, BigDecimal baseAmount) {
        BigDecimal moistureGain = getLearnedMoistureGain(pointId);

        BigDecimal adjusted = baseAmount.multiply(DEFAULT_MOISTURE_GAIN)
                .divide(moistureGain, 4, RoundingMode.HALF_UP);

        log.debug("调整用水量: base={}, adjusted={}, moistureGain={}",
                baseAmount, adjusted, moistureGain);

        return adjusted;
    }

    @Transactional
    protected void updateLearnedMoistureGain(Long pointId, BigDecimal newValue) {
        IrrigationThresholdConfig config = getThresholdConfig(pointId);

        int newCount = (config.getLearningSampleCount() != null ? config.getLearningSampleCount() : 0) + 1;
        BigDecimal oldValue = config.getLearnedMoistureGain() != null ? config.getLearnedMoistureGain() : DEFAULT_MOISTURE_GAIN;

        double learningRate = Math.max(MIN_LEARNING_RATE,
                Math.min(MAX_LEARNING_RATE, 1.0 / Math.min(newCount, 10)));

        BigDecimal updatedValue = oldValue.multiply(BigDecimal.valueOf(1 - learningRate))
                .add(newValue.multiply(BigDecimal.valueOf(learningRate)));

        BigDecimal newConfidence = BigDecimal.valueOf(
                Math.min(0.95, 0.30 + newCount * 0.05));

        config.setLearnedMoistureGain(updatedValue.setScale(4, RoundingMode.HALF_UP));
        config.setLearningSampleCount(newCount);
        config.setLearningConfidence(newConfidence.setScale(2, RoundingMode.HALF_UP));
        config.setLastLearningAt(LocalDateTime.now());

        configMapper.updateById(config);

        log.info("更新学习参数: pointId={}, oldValue={}, newValue={}, confidence={}",
                pointId, oldValue, updatedValue, newConfidence);
    }

    private IrrigationThresholdConfig createDefaultConfig(Long pointId) {
        IrrigationThresholdConfig config = new IrrigationThresholdConfig();
        config.setPointId(pointId);
        config.setMoistureThreshold(40);
        config.setMaxSingleIrrigation(180);
        config.setMinIrrigationInterval(30);
        config.setEnablePredictive(1);
        config.setEnableAutoControl(1);
        config.setPredictionMode("ewma");
        config.setLearnedMoistureGain(DEFAULT_MOISTURE_GAIN);
        config.setLearningSampleCount(0);
        config.setLearningConfidence(new BigDecimal("0.00"));

        configMapper.insert(config);
        return config;
    }
}
