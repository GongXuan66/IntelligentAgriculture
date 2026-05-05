package com.agriculture.service.impl;

import com.agriculture.entity.SensorData;
import com.agriculture.mapper.SensorDataMapper;
import com.agriculture.model.dto.MoisturePredictionDTO;
import com.agriculture.service.MoisturePredictor;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class MoisturePredictorImpl implements MoisturePredictor {

    private final SensorDataMapper sensorDataMapper;

    private static final double ALPHA = 0.3;
    private static final int TREND_WINDOW = 3;

    @Override
    public MoisturePredictionDTO predict(Long pointId, int hoursAhead) {
        MoisturePredictionDTO result = new MoisturePredictionDTO();

        LocalDateTime startTime = LocalDateTime.now().minusHours(24);
        LocalDateTime endTime = LocalDateTime.now();
        List<SensorData> sensorDataList = sensorDataMapper.findByPointIdAndTimeRange(pointId, startTime, endTime);

        if (sensorDataList == null || sensorDataList.isEmpty()) {
            result.setNeedPreIrrigation(false);
            result.setReason("无历史数据，无法预测");
            result.setConfidence(BigDecimal.ZERO);
            return result;
        }

        List<Double> history = sensorDataList.stream()
                .sorted((a, b) -> a.getRecordedAt().compareTo(b.getRecordedAt()))
                .map(d -> d.getSoilMoisture().doubleValue())
                .collect(Collectors.toList());

        double ewma = calculateEWMA(history);
        double trend = calculateTrend(history);

        double current = history.get(history.size() - 1);
        result.setCurrentMoisture(BigDecimal.valueOf(current).setScale(1, RoundingMode.HALF_UP));

        double predict2h = ewma + trend * 2;
        double predict4h = ewma + trend * 4;
        double predict6h = ewma + trend * 6;

        result.setPredict2h(BigDecimal.valueOf(predict2h).setScale(1, RoundingMode.HALF_UP));
        result.setPredict4h(BigDecimal.valueOf(predict4h).setScale(1, RoundingMode.HALF_UP));
        result.setPredict6h(BigDecimal.valueOf(predict6h).setScale(1, RoundingMode.HALF_UP));

        if (trend > 0.5) {
            result.setTrend("rising");
        } else if (trend < -0.5) {
            result.setTrend("falling");
        } else {
            result.setTrend("stable");
        }

        double confidence = Math.min(0.9, 0.3 + history.size() * 0.02);
        result.setConfidence(BigDecimal.valueOf(confidence).setScale(2, RoundingMode.HALF_UP));

        return result;
    }

    @Override
    public MoisturePredictionDTO analyze(Long pointId, double threshold) {
        MoisturePredictionDTO result = predict(pointId, 4);

        if (result.getCurrentMoisture() == null) {
            return result;
        }

        double current = result.getCurrentMoisture().doubleValue();
        double predict2h = result.getPredict2h() != null ? result.getPredict2h().doubleValue() : current;
        double predict4h = result.getPredict4h() != null ? result.getPredict4h().doubleValue() : current;

        if ("falling".equals(result.getTrend()) && predict2h < threshold && current >= threshold) {
            result.setNeedPreIrrigation(true);
            result.setReason(String.format("预测2小时后湿度将降至%.1f%%，建议提前灌溉", predict2h));
        } else if (predict4h < threshold * 0.9) {
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

    @Override
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

    private double calculateEWMA(List<Double> history) {
        if (history.isEmpty()) return 0;

        double ewma = history.get(0);
        for (int i = 1; i < history.size(); i++) {
            ewma = ALPHA * history.get(i) + (1 - ALPHA) * ewma;
        }
        return ewma;
    }

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
