package com.agriculture.service;

import com.agriculture.mapper.MoistureHistoryMapper;
import com.agriculture.model.dto.MoisturePredictionDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

/**
 * EWMA湿度预测算法测试
 */
@ExtendWith(MockitoExtension.class)
class MoisturePredictorTest {

    @Mock
    private MoistureHistoryMapper moistureHistoryMapper;

    @InjectMocks
    private MoisturePredictor moisturePredictor;

    private static final Long POINT_ID = 1L;

    @BeforeEach
    void setUp() {
        // 默认返回空列表
        when(moistureHistoryMapper.findMoistureValuesByPointId(any(), any()))
                .thenReturn(Collections.emptyList());
    }

    // ========== EWMA计算测试 ==========

    @Test
    @DisplayName("EWMA计算 - 稳定趋势数据")
    void testEWMA_StableTrend() {
        // 模拟稳定的湿度数据 (50%左右波动)
        List<Double> stableData = Arrays.asList(
                50.0, 51.0, 49.0, 50.0, 51.0, 50.0, 49.0, 50.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(stableData);

        MoisturePredictionDTO result = moisturePredictor.predict(POINT_ID, 2);

        assertNotNull(result);
        assertEquals("stable", result.getTrend());
        // 稳定数据预测值应接近当前值
        assertTrue(result.getPredict2h().compareTo(new BigDecimal("45")) > 0);
        assertTrue(result.getPredict2h().compareTo(new BigDecimal("55")) < 0);
    }

    @Test
    @DisplayName("EWMA计算 - 下降趋势数据")
    void testEWMA_FallingTrend() {
        // 模拟持续下降的湿度数据
        List<Double> fallingData = Arrays.asList(
                55.0, 52.0, 49.0, 46.0, 43.0, 40.0, 37.0, 34.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(fallingData);

        MoisturePredictionDTO result = moisturePredictor.predict(POINT_ID, 4);

        assertNotNull(result);
        assertEquals("falling", result.getTrend());
        // 下降趋势预测值应小于当前值
        assertTrue(result.getPredict4h().compareTo(result.getCurrentMoisture()) < 0);
    }

    @Test
    @DisplayName("EWMA计算 - 上升趋势数据")
    void testEWMA_RisingTrend() {
        // 模拟上升的湿度数据（可能是灌溉后）
        List<Double> risingData = Arrays.asList(
                30.0, 33.0, 38.0, 42.0, 46.0, 48.0, 50.0, 51.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(risingData);

        MoisturePredictionDTO result = moisturePredictor.predict(POINT_ID, 2);

        assertNotNull(result);
        assertEquals("rising", result.getTrend());
        // 上升趋势预测值应大于当前值
        assertTrue(result.getPredict2h().compareTo(result.getCurrentMoisture()) > 0);
    }

    // ========== 预防性灌溉决策测试 ==========

    @Test
    @DisplayName("预防性灌溉 - 下降趋势接近阈值应触发")
    void testPreIrrigation_ShouldTrigger_WhenFallingNearThreshold() {
        // 当前45%，持续下降，阈值40%
        List<Double> fallingData = Arrays.asList(
                55.0, 52.0, 49.0, 47.0, 45.0, 43.0, 42.0, 41.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(fallingData);

        MoisturePredictionDTO result = moisturePredictor.analyze(POINT_ID, 40.0);

        assertNotNull(result);
        assertTrue(result.getNeedPreIrrigation());
        assertTrue(result.getReason().contains("预测"));
    }

    @Test
    @DisplayName("预防性灌溉 - 稳定趋势不应触发")
    void testPreIrrigation_ShouldNotTrigger_WhenStable() {
        // 当前50%，稳定，阈值40%
        List<Double> stableData = Arrays.asList(
                50.0, 50.5, 49.5, 50.0, 50.2, 49.8, 50.0, 50.1
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(stableData);

        MoisturePredictionDTO result = moisturePredictor.analyze(POINT_ID, 40.0);

        assertNotNull(result);
        assertFalse(result.getNeedPreIrrigation());
        assertTrue(result.getReason().contains("正常") || result.getReason().contains("无需"));
    }

    @Test
    @DisplayName("预防性灌溉 - 当前已低于阈值应立即灌溉")
    void testPreIrrigation_ShouldIrrigateNow_WhenBelowThreshold() {
        // 当前35%，低于阈值40%
        List<Double> lowData = Arrays.asList(
                45.0, 42.0, 40.0, 38.0, 36.0, 35.0, 34.0, 33.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(lowData);

        MoisturePredictionDTO result = moisturePredictor.analyze(POINT_ID, 40.0);

        assertNotNull(result);
        assertFalse(result.getNeedPreIrrigation()); // 不是预防性，是立即灌溉
        assertTrue(result.getReason().contains("立即灌溉"));
    }

    // ========== 边界条件测试 ==========

    @Test
    @DisplayName("边界条件 - 无历史数据")
    void testBoundary_NoHistoryData() {
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(Collections.emptyList());

        MoisturePredictionDTO result = moisturePredictor.predict(POINT_ID, 2);

        assertNotNull(result);
        assertFalse(result.getNeedPreIrrigation());
        assertEquals(BigDecimal.ZERO, result.getConfidence());
        assertTrue(result.getReason().contains("无历史数据"));
    }

    @Test
    @DisplayName("边界条件 - 单条历史数据")
    void testBoundary_SingleDataPoint() {
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(Collections.singletonList(50.0));

        MoisturePredictionDTO result = moisturePredictor.predict(POINT_ID, 2);

        assertNotNull(result);
        // 单条数据趋势应为stable
        assertEquals("stable", result.getTrend());
    }

    @Test
    @DisplayName("边界条件 - 预测时长为0")
    void testBoundary_ZeroHoursAhead() {
        List<Double> data = Arrays.asList(50.0, 51.0, 50.0);
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(data);

        double result = moisturePredictor.predictValue(POINT_ID, 0);

        // 预测0小时应接近当前EWMA值
        assertTrue(result > 0);
    }

    // ========== 置信度测试 ==========

    @Test
    @DisplayName("置信度 - 数据量越多置信度越高")
    void testConfidence_MoreDataHigherConfidence() {
        // 少量数据
        List<Double> littleData = Arrays.asList(50.0, 51.0, 49.0);
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(littleData);

        MoisturePredictionDTO result1 = moisturePredictor.predict(POINT_ID, 2);
        BigDecimal confidence1 = result1.getConfidence();

        // 大量数据
        List<Double> moreData = Arrays.asList(
                50.0, 51.0, 49.0, 50.0, 52.0, 48.0, 51.0, 49.0,
                50.0, 51.0, 49.0, 50.0, 52.0, 48.0, 51.0, 49.0,
                50.0, 51.0, 49.0, 50.0, 52.0, 48.0, 51.0, 49.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(moreData);

        MoisturePredictionDTO result2 = moisturePredictor.predict(POINT_ID, 2);
        BigDecimal confidence2 = result2.getConfidence();

        assertTrue(confidence2.compareTo(confidence1) > 0);
    }

    @Test
    @DisplayName("置信度 - 最大不超过0.9")
    void testConfidence_MaxValue() {
        // 极大量数据
        List<Double> hugeData = Collections.nCopies(100, 50.0);
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(hugeData);

        MoisturePredictionDTO result = moisturePredictor.predict(POINT_ID, 2);

        assertTrue(result.getConfidence().compareTo(new BigDecimal("0.9")) <= 0);
    }

    // ========== 实际场景模拟测试 ==========

    @Test
    @DisplayName("实际场景 - 高温天气快速蒸发")
    void testScenario_HighTemperatureEvaporation() {
        // 模拟高温天气下湿度快速下降
        // 早上60% -> 中午45% -> 下午35%
        List<Double> hotDayData = Arrays.asList(
                60.0, 58.0, 55.0, 52.0, 48.0, 45.0, 42.0, 38.0, 35.0
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(hotDayData);

        MoisturePredictionDTO result = moisturePredictor.analyze(POINT_ID, 40.0);

        assertNotNull(result);
        assertEquals("falling", result.getTrend());
        // 应该建议预防性灌溉
        assertTrue(result.getNeedPreIrrigation() || 
                   result.getCurrentMoisture().compareTo(new BigDecimal("40")) < 0);
    }

    @Test
    @DisplayName("实际场景 - 灌溉后湿度回升")
    void testScenario_AfterIrrigation() {
        // 灌溉后湿度从30%回升到50%
        List<Double> afterIrrigationData = Arrays.asList(
                30.0, 35.0, 40.0, 44.0, 47.0, 49.0, 50.0, 50.5
        );
        when(moistureHistoryMapper.findMoistureValuesByPointId(eq(POINT_ID), any()))
                .thenReturn(afterIrrigationData);

        MoisturePredictionDTO result = moisturePredictor.analyze(POINT_ID, 40.0);

        assertNotNull(result);
        assertEquals("rising", result.getTrend());
        assertFalse(result.getNeedPreIrrigation());
    }
}
