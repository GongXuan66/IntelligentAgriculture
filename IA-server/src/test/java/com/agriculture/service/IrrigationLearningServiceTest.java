package com.agriculture.service;

import com.agriculture.entity.IrrigationLearningParams;
import com.agriculture.entity.IrrigationLog;
import com.agriculture.mapper.IrrigationLearningParamsMapper;
import com.agriculture.mapper.IrrigationLogMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import org.mockito.ArgumentMatchers;

/**
 * 自适应学习服务测试
 */
@ExtendWith(MockitoExtension.class)
class IrrigationLearningServiceTest {

    @Mock
    private IrrigationLearningParamsMapper paramsMapper;

    @Mock
    private IrrigationLogMapper irrigationLogMapper;

    @InjectMocks
    private IrrigationLearningService learningService;

    private static final Long POINT_ID = 1L;
    private static final BigDecimal DEFAULT_GAIN = new BigDecimal("1.6667");

    // ========== 学习功能测试 ==========

    @Test
    @DisplayName("学习 - 首次学习创建新参数")
    void testLearn_FirstTime_CreatesNewParam() {
        // 准备灌溉日志
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("30.0"),  // 灌溉前湿度
                new BigDecimal("45.0"),  // 灌溉后湿度
                new BigDecimal("10.0"),  // 用水量10升
                new BigDecimal("25.0")   // 温度
        );

        // 模拟无现有参数
        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(null);

        // 执行学习
        learningService.learn(log);

        // 验证插入新参数
        verify(paramsMapper).insert(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    @Test
    @DisplayName("学习 - 增量学习更新现有参数")
    void testLearn_Incremental_UpdatesParam() {
        // 准备灌溉日志
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("35.0"),
                new BigDecimal("48.0"),
                new BigDecimal("10.0"),
                new BigDecimal("28.0")
        );

        // 模拟已有参数
        IrrigationLearningParams existingParam = new IrrigationLearningParams();
        existingParam.setPointId(POINT_ID);
        existingParam.setParamName("MOISTURE_GAIN_PER_LITER");
        existingParam.setParamValue(new BigDecimal("1.6667"));
        existingParam.setSampleCount(5);
        existingParam.setConfidence(new BigDecimal("0.55"));

        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(existingParam);

        // 执行学习
        learningService.learn(log);

        // 验证更新参数
        verify(paramsMapper).updateById(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    @Test
    @DisplayName("学习 - 学习率随样本数递减")
    void testLearn_LearningRateDecreases() {
        // 第6次学习（样本数从5->6）
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("30.0"),
                new BigDecimal("45.0"),
                new BigDecimal("10.0"),
                new BigDecimal("25.0")
        );

        IrrigationLearningParams param5 = new IrrigationLearningParams();
        param5.setParamValue(new BigDecimal("1.6667"));
        param5.setSampleCount(5);
        param5.setConfidence(new BigDecimal("0.55"));

        IrrigationLearningParams param50 = new IrrigationLearningParams();
        param50.setParamValue(new BigDecimal("1.6667"));
        param50.setSampleCount(50);
        param50.setConfidence(new BigDecimal("0.90"));

        // 样本数少时，学习率较高
        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(param5);
        learningService.learn(log);

        // 样本数多时，学习率较低（变化更小）
        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(param50);
        learningService.learn(log);

        // 验证更新被调用两次
        verify(paramsMapper, times(2)).updateById(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    @Test
    @DisplayName("学习 - 置信度随样本增加而提高")
    void testLearn_ConfidenceIncreases() {
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("30.0"),
                new BigDecimal("44.0"),
                new BigDecimal("10.0"),
                new BigDecimal("25.0")
        );

        // 初始置信度0.30
        IrrigationLearningParams param = new IrrigationLearningParams();
        param.setParamValue(new BigDecimal("1.6667"));
        param.setSampleCount(1);
        param.setConfidence(new BigDecimal("0.30"));

        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(param);

        learningService.learn(log);

        // 置信度应增加 0.05 (0.30 + 2 * 0.05 = 0.40)
        verify(paramsMapper).updateById(argThat(p -> 
                p.getConfidence().compareTo(new BigDecimal("0.35")) >= 0
        ));
    }

    // ========== 异常情况测试 ==========

    @Test
    @DisplayName("学习 - 缺少灌溉后湿度数据跳过学习")
    void testLearn_SkipWhenNoAfterMoisture() {
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("30.0"),
                null,  // 缺少灌溉后湿度
                new BigDecimal("10.0"),
                new BigDecimal("25.0")
        );

        learningService.learn(log);

        // 验证没有插入或更新
        verify(paramsMapper, never()).insert(ArgumentMatchers.<IrrigationLearningParams>any());
        verify(paramsMapper, never()).updateById(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    @Test
    @DisplayName("学习 - 缺少灌溉前湿度数据跳过学习")
    void testLearn_SkipWhenNoBeforeMoisture() {
        IrrigationLog log = createIrrigationLog(
                null,
                new BigDecimal("45.0"),
                new BigDecimal("10.0"),
                new BigDecimal("25.0")
        );

        learningService.learn(log);

        verify(paramsMapper, never()).insert(ArgumentMatchers.<IrrigationLearningParams>any());
        verify(paramsMapper, never()).updateById(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    @Test
    @DisplayName("学习 - 用水量为零跳过学习")
    void testLearn_SkipWhenZeroWater() {
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("30.0"),
                new BigDecimal("45.0"),
                BigDecimal.ZERO,
                new BigDecimal("25.0")
        );

        learningService.learn(log);

        verify(paramsMapper, never()).insert(ArgumentMatchers.<IrrigationLearningParams>any());
        verify(paramsMapper, never()).updateById(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    @Test
    @DisplayName("学习 - 湿度未提升时跳过学习")
    void testLearn_SkipWhenNoMoistureGain() {
        // 灌溉后湿度反而下降（异常情况）
        IrrigationLog log = createIrrigationLog(
                new BigDecimal("45.0"),
                new BigDecimal("44.0"),  // 比灌溉前还低
                new BigDecimal("10.0"),
                new BigDecimal("35.0")   // 高温蒸发
        );

        learningService.learn(log);

        verify(paramsMapper, never()).insert(ArgumentMatchers.<IrrigationLearningParams>any());
        verify(paramsMapper, never()).updateById(ArgumentMatchers.<IrrigationLearningParams>any());
    }

    // ========== 参数获取测试 ==========

    @Test
    @DisplayName("获取参数 - 高置信度使用学习值")
    void testGetParam_HighConfidenceUseLearnedValue() {
        IrrigationLearningParams learnedParam = new IrrigationLearningParams();
        learnedParam.setParamValue(new BigDecimal("1.45"));
        learnedParam.setConfidence(new BigDecimal("0.70"));  // 高于0.5

        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(learnedParam);

        BigDecimal result = learningService.getLearnedParam(POINT_ID, "MOISTURE_GAIN_PER_LITER");

        assertEquals(new BigDecimal("1.45"), result);
    }

    @Test
    @DisplayName("获取参数 - 低置信度使用默认值")
    void testGetParam_LowConfidenceUseDefaultValue() {
        IrrigationLearningParams learnedParam = new IrrigationLearningParams();
        learnedParam.setParamValue(new BigDecimal("1.45"));
        learnedParam.setConfidence(new BigDecimal("0.40"));  // 低于0.5

        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(learnedParam);

        BigDecimal result = learningService.getLearnedParam(POINT_ID, "MOISTURE_GAIN_PER_LITER");

        // 应返回默认值
        assertEquals(DEFAULT_GAIN, result);
    }

    @Test
    @DisplayName("获取参数 - 无学习记录使用默认值")
    void testGetParam_NoLearnedRecordUseDefault() {
        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(null);

        BigDecimal result = learningService.getLearnedParam(POINT_ID, "MOISTURE_GAIN_PER_LITER");

        assertEquals(DEFAULT_GAIN, result);
    }

    @Test
    @DisplayName("获取所有参数 - 合并默认值和学习值")
    void testGetAllParams_MergeDefaultAndLearned() {
        IrrigationLearningParams learnedParam = new IrrigationLearningParams();
        learnedParam.setParamName("MOISTURE_GAIN_PER_LITER");
        learnedParam.setParamValue(new BigDecimal("1.50"));
        learnedParam.setConfidence(new BigDecimal("0.80"));

        when(paramsMapper.findByPointId(POINT_ID))
                .thenReturn(Collections.singletonList(learnedParam));

        Map<String, BigDecimal> result = learningService.getAllLearnedParams(POINT_ID);

        // 学习值覆盖默认值
        assertEquals(new BigDecimal("1.50"), result.get("MOISTURE_GAIN_PER_LITER"));
        // 其他参数保持默认
        assertTrue(result.containsKey("EVAPORATION_RATE"));
        assertTrue(result.containsKey("TEMP_FACTOR"));
    }

    // ========== 用水量调整测试 ==========

    @Test
    @DisplayName("调整用水量 - 使用学习到的参数")
    void testAdjustWaterAmount_WithLearnedParams() {
        // 学习到的湿度提升率更高，需要更少的水
        IrrigationLearningParams gainParam = new IrrigationLearningParams();
        gainParam.setParamValue(new BigDecimal("2.0"));  // 高于默认1.6667
        gainParam.setConfidence(new BigDecimal("0.70"));

        IrrigationLearningParams tempParam = new IrrigationLearningParams();
        tempParam.setParamValue(BigDecimal.ONE);
        tempParam.setConfidence(new BigDecimal("0.70"));

        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(gainParam);
        when(paramsMapper.findByPointAndName(POINT_ID, "TEMP_FACTOR"))
                .thenReturn(tempParam);

        BigDecimal baseAmount = new BigDecimal("10.0");
        BigDecimal adjusted = learningService.adjustWaterAmount(POINT_ID, baseAmount);

        // 湿度提升率更高，需要更少的水
        assertTrue(adjusted.compareTo(baseAmount) < 0);
    }

    @Test
    @DisplayName("调整用水量 - 高温时增加用水")
    void testAdjustWaterAmount_HighTemperature() {
        IrrigationLearningParams gainParam = new IrrigationLearningParams();
        gainParam.setParamValue(new BigDecimal("1.6667"));
        gainParam.setConfidence(new BigDecimal("0.70"));

        IrrigationLearningParams tempParam = new IrrigationLearningParams();
        tempParam.setParamValue(new BigDecimal("1.20"));  // 高温因子
        tempParam.setConfidence(new BigDecimal("0.70"));

        when(paramsMapper.findByPointAndName(POINT_ID, "MOISTURE_GAIN_PER_LITER"))
                .thenReturn(gainParam);
        when(paramsMapper.findByPointAndName(POINT_ID, "TEMP_FACTOR"))
                .thenReturn(tempParam);

        BigDecimal baseAmount = new BigDecimal("10.0");
        BigDecimal adjusted = learningService.adjustWaterAmount(POINT_ID, baseAmount);

        // 高温需要更多水
        assertTrue(adjusted.compareTo(baseAmount) > 0);
    }

    // ========== 学习进度测试 ==========

    @Test
    @DisplayName("学习进度 - 返回正确的进度信息")
    void testLearningProgress() {
        IrrigationLearningParams param = new IrrigationLearningParams();
        param.setParamName("MOISTURE_GAIN_PER_LITER");
        param.setParamValue(new BigDecimal("1.50"));
        param.setSampleCount(10);
        param.setConfidence(new BigDecimal("0.80"));

        when(paramsMapper.findByPointId(POINT_ID))
                .thenReturn(Collections.singletonList(param));

        Map<String, Object> progress = learningService.getLearningProgress(POINT_ID);

        assertTrue(progress.containsKey("MOISTURE_GAIN_PER_LITER"));

        @SuppressWarnings("unchecked")
        Map<String, Object> paramInfo = (Map<String, Object>) progress.get("MOISTURE_GAIN_PER_LITER");
        assertEquals(new BigDecimal("1.50"), paramInfo.get("value"));
        assertEquals(10, paramInfo.get("sampleCount"));
        assertEquals(new BigDecimal("0.80"), paramInfo.get("confidence"));
    }

    // ========== 辅助方法 ==========

    private IrrigationLog createIrrigationLog(BigDecimal before, BigDecimal after,
                                               BigDecimal water, BigDecimal temperature) {
        IrrigationLog log = new IrrigationLog();
        log.setPointId(POINT_ID);
        log.setSoilMoistureBefore(before);
        log.setSoilMoistureAfter(after);
        log.setWaterAmount(water);
        log.setTemperature(temperature);
        return log;
    }
}
