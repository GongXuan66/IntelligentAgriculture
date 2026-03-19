package com.agriculture.service;

import com.agriculture.model.response.AutoIrrigationPlanResponse;
import com.agriculture.model.request.AutoIrrigationRequest;
import com.agriculture.model.response.AutoIrrigationResultResponse;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationDTO;
import com.agriculture.model.request.IrrigationPlanConfig;
import com.agriculture.model.request.IrrigationPlanRequest;
import com.agriculture.entity.IrrigationLog;
import com.agriculture.mapper.IrrigationLogMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class IrrigationService {

    private final IrrigationLogMapper irrigationLogMapper;

    // Flow rate and tuning constants used by auto plan.
    private static final BigDecimal WATER_PER_SECOND = new BigDecimal("0.5");
    private static final BigDecimal SOIL_MOISTURE_GAIN_PER_LITER = new BigDecimal("1.6666667"); // 1 / 0.6
    private static final int MIN_AUTO_DURATION_SEC = 10;
    private static final int MAX_AUTO_DURATION_SEC = 180;

    public List<IrrigationDTO> getLogsByPointId(Long pointId) {
        return irrigationLogMapper.findByPointIdOrderByStartTimeDesc(pointId).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public Page<IrrigationDTO> getLogsPaged(Long pointId, int pageNum, int pageSize) {
        Page<IrrigationLog> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<IrrigationLog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(IrrigationLog::getPointId, pointId)
               .orderByDesc(IrrigationLog::getStartTime);
        Page<IrrigationLog> logPage = irrigationLogMapper.selectPage(page, wrapper);

        Page<IrrigationDTO> dtoPage = new Page<>(pageNum + 1, pageSize);
        dtoPage.setTotal(logPage.getTotal());
        dtoPage.setRecords(logPage.getRecords().stream().map(this::toDTO).collect(Collectors.toList()));
        return dtoPage;
    }

    public IrrigationDTO getLatestLog(Long pointId) {
        IrrigationLog log = irrigationLogMapper.findFirstByPointIdOrderByStartTimeDesc(pointId);
        return log != null ? toDTO(log) : null;
    }

    public Double getTotalWaterAmount(Long pointId) {
        return irrigationLogMapper.sumWaterAmountByPointId(pointId);
    }

    @Transactional
    public IrrigationDTO startIrrigation(IrrigationDTO.StartRequest request) {
        IrrigationLog irrigationLog = startIrrigationInternal(
                request.getPointId(),
                request.getDuration(),
                request.getMode()
        );
        return toDTO(irrigationLog);
    }

    @Transactional
    public IrrigationDTO stopIrrigation(Long logId) {
        IrrigationLog irrigationLog = irrigationLogMapper.selectById(logId);
        if (irrigationLog == null) {
            throw new RuntimeException("未找到灌溉日志：" + logId);
        }

        if (irrigationLog.getEndTime() != null) {
            throw new RuntimeException("灌溉已经停止");
        }

        irrigationLog.setEndTime(LocalDateTime.now());

        if (irrigationLog.getStartTime() != null) {
            Duration duration = Duration.between(irrigationLog.getStartTime(), irrigationLog.getEndTime());
            int actualDuration = (int) duration.getSeconds();
            irrigationLog.setDuration(actualDuration);

            BigDecimal actualWaterAmount = WATER_PER_SECOND.multiply(new BigDecimal(actualDuration));
            irrigationLog.setWaterAmount(actualWaterAmount);
        }

        irrigationLogMapper.updateById(irrigationLog);
        log.info("灌溉停止：logId={}， durationSec={}， waterAmountL={}",
                logId, irrigationLog.getDuration(), irrigationLog.getWaterAmount());

        return toDTO(irrigationLog);
    }

    @Transactional
    public void deleteLog(Long id) {
        irrigationLogMapper.deleteById(id);
    }

    /**
    * 基于环境数据计算无状态自动灌溉计划。
     * 此不检查自动模式或最小间隔;这些都会被执行
     * 通过自动启动方法。
     */
    public AutoIrrigationPlanResponse buildAutoPlan(EnvironmentDataDTO envData, IrrigationPlanConfig config) {
        AutoIrrigationPlanResponse plan = new AutoIrrigationPlanResponse();

        if (envData == null || envData.getSoilMoisture() == null) {
            plan.setShouldIrrigate(false);
            plan.setWaterAmountL(BigDecimal.ZERO);
            plan.setDurationSeconds(0);
            plan.setTargetMoisture(BigDecimal.ZERO);
            plan.setMoistureGap(BigDecimal.ZERO);
            plan.setRiskFactor(BigDecimal.ONE);
            plan.setReason("缺少环境数据");
            return plan;
        }

        int threshold = 40;
        if (config != null && config.getMoistureThreshold() != null) {
            threshold = clamp(config.getMoistureThreshold(), 20, 70);
        }

        BigDecimal soilMoisture = clamp(envData.getSoilMoisture(), BigDecimal.ZERO, new BigDecimal("100"));
        if (soilMoisture.compareTo(new BigDecimal(threshold)) >= 0) {
            return buildNoIrrigationPlan(threshold, "土壤水分超过阈值");
        }

        BigDecimal targetMoisture = new BigDecimal(threshold + 12).min(new BigDecimal("75"));
        BigDecimal moistureGap = targetMoisture.subtract(soilMoisture).max(BigDecimal.ZERO);

        BigDecimal baseWaterAmount = moistureGap.divide(SOIL_MOISTURE_GAIN_PER_LITER, 6, RoundingMode.HALF_UP);
        BigDecimal riskFactor = BigDecimal.ONE;

        if (envData.getTemperature() != null) {
            if (envData.getTemperature().compareTo(new BigDecimal("35")) > 0) {
                riskFactor = riskFactor.add(new BigDecimal("0.2"));
            } else if (envData.getTemperature().compareTo(new BigDecimal("30")) > 0) {
                riskFactor = riskFactor.add(new BigDecimal("0.1"));
            } else if (envData.getTemperature().compareTo(new BigDecimal("15")) < 0) {
                riskFactor = riskFactor.subtract(new BigDecimal("0.08"));
            }
        }

        if (envData.getHumidity() != null) {
            if (envData.getHumidity().compareTo(new BigDecimal("40")) < 0) {
                riskFactor = riskFactor.add(new BigDecimal("0.1"));
            } else if (envData.getHumidity().compareTo(new BigDecimal("75")) > 0) {
                riskFactor = riskFactor.subtract(new BigDecimal("0.08"));
            }
        }

        if (envData.getLight() != null) {
            if (envData.getLight().compareTo(new BigDecimal("30000")) > 0) {
                riskFactor = riskFactor.add(new BigDecimal("0.15"));
            } else if (envData.getLight().compareTo(new BigDecimal("15000")) > 0) {
                riskFactor = riskFactor.add(new BigDecimal("0.08"));
            } else if (envData.getLight().compareTo(new BigDecimal("1000")) < 0) {
                riskFactor = riskFactor.subtract(new BigDecimal("0.05"));
            }
        }

        if (envData.getCo2() != null && envData.getCo2().compareTo(new BigDecimal("1000")) > 0) {
            riskFactor = riskFactor.add(new BigDecimal("0.05"));
        }

        riskFactor = clamp(riskFactor, new BigDecimal("0.75"), new BigDecimal("1.45"));
        BigDecimal waterAmount = baseWaterAmount.multiply(riskFactor);
        waterAmount = clamp(waterAmount, new BigDecimal("0.5"), new BigDecimal("45"));

        int rawDuration = waterAmount.divide(WATER_PER_SECOND, 0, RoundingMode.HALF_UP).intValue();
        int durationSeconds = clamp(rawDuration, MIN_AUTO_DURATION_SEC, MAX_AUTO_DURATION_SEC);

        plan.setShouldIrrigate(true);
        plan.setWaterAmountL(waterAmount.setScale(1, RoundingMode.HALF_UP));
        plan.setDurationSeconds(durationSeconds);
        plan.setTargetMoisture(targetMoisture.setScale(1, RoundingMode.HALF_UP));
        plan.setMoistureGap(moistureGap.setScale(1, RoundingMode.HALF_UP));
        plan.setRiskFactor(riskFactor.setScale(2, RoundingMode.HALF_UP));
        plan.setReason("根据环境和门槛自动计划");
        return plan;
    }

    /**
     * Plan-only API for clients.
     */
    public AutoIrrigationPlanResponse buildAutoPlan(IrrigationPlanRequest request) {
        Long pointId = request != null ? request.getPointId() : null;
        EnvironmentDataDTO envData = request != null ? request.getEnvData() : null;
        IrrigationPlanConfig config = request != null ? request.getConfig() : null;

        if (pointId == null) {
            pointId = 1L;
        }
        return buildAutoPlan(envData, config);
    }

    /**
     *如果配置和时间规则允许，计算计划并开始灌溉
     */
    @Transactional
    public AutoIrrigationResultResponse startAutoIrrigation(AutoIrrigationRequest request) {
        Long pointId = request != null ? request.getPointId() : null;
        EnvironmentDataDTO envData = request != null ? request.getEnvData() : null;
        IrrigationPlanConfig config = request != null ? request.getConfig() : null;

        if (pointId == null) {
            pointId = 1L;
        }

        AutoIrrigationPlanResponse plan = buildAutoPlan(envData, config);

        if (config == null || config.getAutoMode() == null || !config.getAutoMode()) {
            plan.setShouldIrrigate(false);
            plan.setReason("自动模式已禁用");
        }

        if (plan.isShouldIrrigate() && isCurrentlyIrrigating(pointId)) {
            plan.setShouldIrrigate(false);
            plan.setReason("灌溉系统已经开始运行");
        }

        if (plan.isShouldIrrigate()) {
            int minInterval = config != null && config.getMinInterval() != null ? config.getMinInterval() : 0;
            if (!isAutoIntervalOk(pointId, minInterval)) {
                plan.setShouldIrrigate(false);
                plan.setReason("最短间隔尚未过去");
            }
        }

        AutoIrrigationResultResponse result = new AutoIrrigationResultResponse();
        result.setPlan(plan);

        if (plan.isShouldIrrigate()) {
            IrrigationLog logEntity = startIrrigationInternal(pointId, plan.getDurationSeconds(), 0);
            result.setLog(toDTO(logEntity));
            result.setStarted(true);
        } else {
            result.setStarted(false);
            result.setLog(null);
        }

        return result;
    }

    private IrrigationLog startIrrigationInternal(Long pointId, Integer duration, Integer mode) {
        IrrigationLog irrigationLog = new IrrigationLog();
        irrigationLog.setPointId(pointId);
        irrigationLog.setDuration(duration);
        irrigationLog.setMode(mode);
        irrigationLog.setStartTime(LocalDateTime.now());

        BigDecimal waterAmount = WATER_PER_SECOND.multiply(new BigDecimal(duration));
        irrigationLog.setWaterAmount(waterAmount);

        irrigationLogMapper.insert(irrigationLog);
        log.info("灌溉开始： pointId={}， durationSec={}， waterAmountL={}， mode={}",
                pointId, duration, waterAmount, mode);
        return irrigationLog;
    }

    private boolean isCurrentlyIrrigating(Long pointId) {
        IrrigationLog active = irrigationLogMapper.findActiveByPointId(pointId);
        return active != null;
    }

    private boolean isAutoIntervalOk(Long pointId, int minIntervalSeconds) {
        if (minIntervalSeconds <= 0) {
            return true;
        }

        IrrigationLog lastAuto = irrigationLogMapper.findLastAutoByPointId(pointId);
        if (lastAuto == null || lastAuto.getStartTime() == null) {
            return true;
        }

        Duration elapsed = Duration.between(lastAuto.getStartTime(), LocalDateTime.now());
        return elapsed.getSeconds() >= minIntervalSeconds;
    }

    private AutoIrrigationPlanResponse buildNoIrrigationPlan(int targetMoisture, String reason) {
        AutoIrrigationPlanResponse plan = new AutoIrrigationPlanResponse();
        plan.setShouldIrrigate(false);
        plan.setWaterAmountL(BigDecimal.ZERO);
        plan.setDurationSeconds(0);
        plan.setTargetMoisture(new BigDecimal(targetMoisture).setScale(1, RoundingMode.HALF_UP));
        plan.setMoistureGap(BigDecimal.ZERO);
        plan.setRiskFactor(BigDecimal.ONE);
        plan.setReason(reason);
        return plan;
    }

    private int clamp(int value, int min, int max) {
        return Math.max(min, Math.min(max, value));
    }

    private BigDecimal clamp(BigDecimal value, BigDecimal min, BigDecimal max) {
        if (value.compareTo(min) < 0) {
            return min;
        }
        if (value.compareTo(max) > 0) {
            return max;
        }
        return value;
    }

    private IrrigationDTO toDTO(IrrigationLog irrigationLog) {
        IrrigationDTO dto = new IrrigationDTO();
        dto.setId(irrigationLog.getId());
        dto.setPointId(irrigationLog.getPointId());
        dto.setWaterAmount(irrigationLog.getWaterAmount());
        dto.setDuration(irrigationLog.getDuration());
        dto.setMode(irrigationLog.getMode());
        dto.setStartTime(irrigationLog.getStartTime());
        dto.setEndTime(irrigationLog.getEndTime());
        dto.setCreatedAt(irrigationLog.getCreatedAt());
        return dto;
    }
}
