package com.agriculture.service;

import com.agriculture.entity.IrrigationThresholdConfig;
import com.agriculture.entity.IrrigationLog;
import com.agriculture.mapper.IrrigationThresholdConfigMapper;
import com.agriculture.mapper.IrrigationLogMapper;
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

/**
 * 灌溉自适应学习服务
 * 根据每次灌溉的实际效果自动调整参数
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class IrrigationLearningService {

    private final IrrigationThresholdConfigMapper configMapper;

    // 默认参数值
    private static final BigDecimal DEFAULT_MOISTURE_GAIN = new BigDecimal("1.5000");
    private static final BigDecimal DEFAULT_EVAPORATION_RATE = new BigDecimal("0.5");
    private static final BigDecimal DEFAULT_TEMP_FACTOR = BigDecimal.ONE;

    // 学习率上限
    private static final double MAX_LEARNING_RATE = 0.3;
    private static final double MIN_LEARNING_RATE = 0.05;

    /**
     * 从灌溉完成事件中学习
     */
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

        // 计算实际效果
        BigDecimal actualGain = irrigationLog.getSoilMoistureAfter().subtract(irrigationLog.getSoilMoistureBefore());
        if (actualGain.compareTo(BigDecimal.ZERO) <= 0) {
            log.warn("灌溉后湿度未提升，可能存在数据异常");
            return;
        }

        // 计算实际的"每升水提升湿度"
        BigDecimal actualGainPerLiter = actualGain.divide(irrigationLog.getWaterAmount(), 4, RoundingMode.HALF_UP);

        // 更新学习参数
        updateLearnedMoistureGain(irrigationLog.getPointId(), actualGainPerLiter);

        log.info("学习完成: pointId={}, 实际每升提升湿度={}", irrigationLog.getPointId(), actualGainPerLiter);
    }

    /**
     * 获取检测点的阈值配置
     */
    public IrrigationThresholdConfig getThresholdConfig(Long pointId) {
        LambdaQueryWrapper<IrrigationThresholdConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(IrrigationThresholdConfig::getPointId, pointId);
        IrrigationThresholdConfig config = configMapper.selectOne(wrapper);
        
        if (config == null) {
            // 创建默认配置
            config = createDefaultConfig(pointId);
        }
        
        return config;
    }

    /**
     * 获取学习到的湿度提升率
     */
    public BigDecimal getLearnedMoistureGain(Long pointId) {
        IrrigationThresholdConfig config = getThresholdConfig(pointId);
        if (config.getLearnedMoistureGain() != null 
                && config.getLearningConfidence() != null 
                && config.getLearningConfidence().compareTo(new BigDecimal("0.5")) >= 0) {
            return config.getLearnedMoistureGain();
        }
        return DEFAULT_MOISTURE_GAIN;
    }

    /**
     * 获取某检测点的所有学习参数
     */
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

    /**
     * 获取学习进度（用于前端展示）
     */
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

    /**
     * 更新学习参数
     */
    @Transactional
    protected void updateLearnedMoistureGain(Long pointId, BigDecimal newValue) {
        IrrigationThresholdConfig config = getThresholdConfig(pointId);

        int newCount = (config.getLearningSampleCount() != null ? config.getLearningSampleCount() : 0) + 1;
        BigDecimal oldValue = config.getLearnedMoistureGain() != null ? config.getLearnedMoistureGain() : DEFAULT_MOISTURE_GAIN;

        // 学习率随样本数递减
        double learningRate = Math.max(MIN_LEARNING_RATE,
                Math.min(MAX_LEARNING_RATE, 1.0 / Math.min(newCount, 10)));

        BigDecimal updatedValue = oldValue.multiply(BigDecimal.valueOf(1 - learningRate))
                .add(newValue.multiply(BigDecimal.valueOf(learningRate)));

        // 更新置信度
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

    /**
     * 创建默认配置
     */
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

    /**
     * 根据学习参数调整用水量
     */
    public BigDecimal adjustWaterAmount(Long pointId, BigDecimal baseAmount) {
        BigDecimal moistureGain = getLearnedMoistureGain(pointId);

        // 使用学习到的参数重新计算
        BigDecimal adjusted = baseAmount.multiply(DEFAULT_MOISTURE_GAIN)
                .divide(moistureGain, 4, RoundingMode.HALF_UP);

        log.debug("调整用水量: base={}, adjusted={}, moistureGain={}",
                baseAmount, adjusted, moistureGain);

        return adjusted;
    }
}