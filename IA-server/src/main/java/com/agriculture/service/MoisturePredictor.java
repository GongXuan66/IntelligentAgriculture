package com.agriculture.service;

import com.agriculture.entity.SensorData;
import com.agriculture.mapper.SensorDataMapper;
import com.agriculture.model.dto.MoisturePredictionDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

/**
 * EWMA湿度预测服务
 * 使用指数加权移动平均进行湿度趋势预测
 * 直接从 sensor_data 表读取历史数据，无需额外建表
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MoisturePredictor {

    private final SensorDataMapper sensorDataMapper;

    // EWMA衰减因子，越大越重视近期数据
    private static final double ALPHA = 0.3;

    // 趋势计算窗口大小
    private static final int TREND_WINDOW = 3;

    /**
     * 预测未来湿度变化
     *
     * @param pointId    检测点ID
     * @param hoursAhead 预测未来几小时
     * @return 预测结果
     */
    public MoisturePredictionDTO predict(Long pointId, int hoursAhead) {
        MoisturePredictionDTO result = new MoisturePredictionDTO();

        // 获取过去24小时的历史数据（从sensor_data表）
        LocalDateTime startTime = LocalDateTime.now().minusHours(24);
        LocalDateTime endTime = LocalDateTime.now();
        List<SensorData> sensorDataList = sensorDataMapper.findByPointIdAndTimeRange(pointId, startTime, endTime);

        if (sensorDataList == null || sensorDataList.isEmpty()) {
            result.setNeedPreIrrigation(false);
            result.setReason("无历史数据，无法预测");
            result.setConfidence(BigDecimal.ZERO);
            return result;
        }

        // 提取土壤湿度值（按时间正序排列）
        List<Double> history = sensorDataList.stream()
                .sorted((a, b) -> a.getRecordedAt().compareTo(b.getRecordedAt()))
                .map(d -> d.getSoilMoisture().doubleValue())
                .collect(Collectors.toList());

        // 计算EWMA平滑值
        double ewma = calculateEWMA(history);

        // 计算趋势
        double trend = calculateTrend(history);

        // 当前湿度
        double current = history.get(history.size() - 1);
        result.setCurrentMoisture(BigDecimal.valueOf(current).setScale(1, RoundingMode.HALF_UP));

        // 预测未来值
        double predict2h = ewma + trend * 2;
        double predict4h = ewma + trend * 4;
        double predict6h = ewma + trend * 6;

        result.setPredict2h(BigDecimal.valueOf(predict2h).setScale(1, RoundingMode.HALF_UP));
        result.setPredict4h(BigDecimal.valueOf(predict4h).setScale(1, RoundingMode.HALF_UP));
        result.setPredict6h(BigDecimal.valueOf(predict6h).setScale(1, RoundingMode.HALF_UP));

        // 判断趋势
        if (trend > 0.5) {
            result.setTrend("rising");
        } else if (trend < -0.5) {
            result.setTrend("falling");
        } else {
            result.setTrend("stable");
        }

        // 计算置信度（基于数据量）
        double confidence = Math.min(0.9, 0.3 + history.size() * 0.02);
        result.setConfidence(BigDecimal.valueOf(confidence).setScale(2, RoundingMode.HALF_UP));

        return result;
    }

    /**
     * 分析是否需要预防性灌溉
     *
     * @param pointId   检测点ID
     * @param threshold 湿度阈值
     * @return 预测分析结果
     */
    public MoisturePredictionDTO analyze(Long pointId, double threshold) {
        MoisturePredictionDTO result = predict(pointId, 4);

        if (result.getCurrentMoisture() == null) {
            return result;
        }

        double current = result.getCurrentMoisture().doubleValue();
        double predict2h = result.getPredict2h() != null ? result.getPredict2h().doubleValue() : current;
        double predict4h = result.getPredict4h() != null ? result.getPredict4h().doubleValue() : current;

        // 下降趋势且预测值低于阈值
        if ("falling".equals(result.getTrend()) && predict2h < threshold && current >= threshold) {
            result.setNeedPreIrrigation(true);
            result.setReason(String.format("预测2小时后湿度将降至%.1f%%，建议提前灌溉", predict2h));
        } else if (predict4h < threshold * 0.9) {
            // 预测值接近危险线
            result.setNeedPreIrrigation(true);
            result.setReason(String.format("预测4小时后湿度将降至%.1f%%，接近临界值", predict4h));
        } else {
            result.setNeedPreIrrigation(false);
            if (current < threshold) {
                result.setReason("当前湿度已低于阈值，需要立即灌溉");
            } else {
                result.setReason("湿度正常，无需预防性灌溉");
            }
        }

        return result;
    }

    /**
     * 预测指定小时后的湿度
     *
     * @param pointId    检测点ID
     * @param hoursAhead 预测时长
     * @return 预测湿度值
     */
    public double predictValue(Long pointId, int hoursAhead) {
        LocalDateTime startTime = LocalDateTime.now().minusHours(24);
        LocalDateTime endTime = LocalDateTime.now();
        List<SensorData> sensorDataList = sensorDataMapper.findByPointIdAndTimeRange(pointId, startTime, endTime);

        if (sensorDataList == null || sensorDataList.isEmpty()) {
            return -1;
        }

        List<Double> history = sensorDataList.stream()
                .sorted((a, b) -> a.getRecordedAt().compareTo(b.getRecordedAt()))
                .map(d -> d.getSoilMoisture().doubleValue())
                .collect(Collectors.toList());

        double ewma = calculateEWMA(history);
        double trend = calculateTrend(history);

        return ewma + trend * hoursAhead;
    }

    /**
     * 计算EWMA平滑值
     */
    private double calculateEWMA(List<Double> history) {
        if (history.isEmpty()) return 0;

        double ewma = history.get(0);
        for (int i = 1; i < history.size(); i++) {
            ewma = ALPHA * history.get(i) + (1 - ALPHA) * ewma;
        }
        return ewma;
    }

    /**
     * 计算趋势（最近几个点的平均变化率）
     */
    private double calculateTrend(List<Double> history) {
        if (history.size() < 2) return 0;

        int window = Math.min(TREND_WINDOW, history.size() - 1);
        double trend = 0;

        for (int i = history.size() - window; i < history.size(); i++) {
            trend += history.get(i) - history.get(i - 1);
        }

        return trend / window;
    }
}