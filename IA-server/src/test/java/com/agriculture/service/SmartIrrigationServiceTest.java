package com.agriculture.service;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.entity.SmartIrrigationDecision;
import com.agriculture.mapper.IrrigationLogMapper;
import com.agriculture.mapper.SmartIrrigationDecisionMapper;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import com.agriculture.model.dto.MoisturePredictionDTO;
import com.agriculture.model.dto.SmartIrrigationPlanDTO;
import com.agriculture.model.request.IrrigationPlanConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.jdbc.core.JdbcTemplate;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Collections;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import org.mockito.ArgumentMatchers;

/**
 * 智能灌溉服务集成测试
 * 测试预测、学习、作物阶段的综合决策
 */
@ExtendWith(MockitoExtension.class)
class SmartIrrigationServiceTest {

    @Mock
    private MoisturePredictor moisturePredictor;

    @Mock
    private IrrigationLearningService learningService;

    @Mock
    private CropStageService cropStageService;

    @Mock
    private IrrigationLogMapper irrigationLogMapper;

    @Mock
    private SmartIrrigationDecisionMapper decisionMapper;

    @Mock
    private JdbcTemplate jdbcTemplate;

    @InjectMocks
    private SmartIrrigationService smartIrrigationService;

    private static final Long POINT_ID = 1L;

    @BeforeEach
    void setUp() {
        // 默认配置
        when(cropStageService.getStrategy(POINT_ID))
                .thenReturn(createDefaultStrategy());
        when(learningService.adjustWaterAmount(eq(POINT_ID), any(BigDecimal.class)))
                .thenAnswer(inv -> inv.getArgument(1)); // 默认不调整
    }

    // ========== 决策类型测试 ==========

    @Test
    @DisplayName("决策类型 - 当前湿度低于阈值触发adaptive决策")
    void testDecisionType_BelowThreshold_Adaptive() {
        // 当前湿度35%，低于阈值40%
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("35"), new BigDecimal("28"), new BigDecimal("50"));

        // 预测返回不需要预防性灌溉
        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("35"), new BigDecimal("33"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        IrrigationPlanConfig config = new IrrigationPlanConfig();
        config.setMoistureThreshold(40);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, config);

        assertTrue(plan.getShouldIrrigate());
        assertEquals("adaptive", plan.getDecisionType());
        assertTrue(plan.getReason().contains("立即灌溉"));
    }

    @Test
    @DisplayName("决策类型 - 预测性灌溉触发predictive决策")
    void testDecisionType_PredictiveIrrigation() {
        // 当前湿度42%，高于阈值40%
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("42"), new BigDecimal("28"), new BigDecimal("50"));

        // 预测2小时后降至38%，需要预防性灌溉
        MoisturePredictionDTO prediction = createPrediction(
                new BigDecimal("42"), new BigDecimal("38"), true, "falling");
        prediction.setReason("预测2小时后湿度将降至38%，建议提前灌溉");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        IrrigationPlanConfig config = new IrrigationPlanConfig();
        config.setMoistureThreshold(40);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, config);

        assertTrue(plan.getShouldIrrigate());
        assertEquals("predictive", plan.getDecisionType());
    }

    @Test
    @DisplayName("决策类型 - 基于作物阶段的决策")
    void testDecisionType_StageBased() {
        // 湿度正常，不需要灌溉
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("55"), new BigDecimal("25"), new BigDecimal("60"));

        MoisturePredictionDTO prediction = createPrediction(
                new BigDecimal("55"), new BigDecimal("54"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        // 有作物配置
        IrrigationStrategyDTO strategy = createTomatoStrategy("开花期", new BigDecimal("0.70"));
        when(cropStageService.getStrategy(POINT_ID)).thenReturn(strategy);

        IrrigationPlanConfig config = new IrrigationPlanConfig();
        config.setMoistureThreshold(40);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, config);

        assertFalse(plan.getShouldIrrigate());
        assertEquals("stage_based", plan.getDecisionType());
    }

    @Test
    @DisplayName("决策类型 - 标准模式（无作物配置）")
    void testDecisionType_Standard() {
        // 湿度正常，不需要灌溉
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("55"), new BigDecimal("25"), new BigDecimal("60"));

        MoisturePredictionDTO prediction = createPrediction(
                new BigDecimal("55"), new BigDecimal("54"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        // 无作物配置
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(false);
        when(cropStageService.getStrategy(POINT_ID)).thenReturn(strategy);

        IrrigationPlanConfig config = new IrrigationPlanConfig();
        config.setMoistureThreshold(40);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, config);

        assertFalse(plan.getShouldIrrigate());
        assertEquals("standard", plan.getDecisionType());
    }

    // ========== 用水量计算测试 ==========

    @Test
    @DisplayName("用水量计算 - 基础计算")
    void testWaterCalculation_Basic() {
        // 当前30%，目标52%，差距22%
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("30"), new BigDecimal("25"), new BigDecimal("50"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("30"), new BigDecimal("28"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        assertNotNull(plan.getWaterAmountL());
        assertTrue(plan.getWaterAmountL().compareTo(BigDecimal.ZERO) > 0);
        assertTrue(plan.getDurationSeconds() >= 10);
        assertTrue(plan.getDurationSeconds() <= 180);
    }

    @Test
    @DisplayName("用水量计算 - 高温增加用水")
    void testWaterCalculation_HighTemperature() {
        // 高温35度
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("30"), new BigDecimal("35"), new BigDecimal("40"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("30"), new BigDecimal("28"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        // 高温下用水量应该更多
        assertNotNull(plan.getWaterAmountL());
    }

    @Test
    @DisplayName("用水量计算 - 低湿增加用水")
    void testWaterCalculation_LowHumidity() {
        // 空气湿度低20%
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("30"), new BigDecimal("25"), new BigDecimal("20"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("30"), new BigDecimal("28"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        assertNotNull(plan.getWaterAmountL());
    }

    @Test
    @DisplayName("用水量计算 - 强光增加用水")
    void testWaterCalculation_HighLight() {
        // 强光30000lux
        EnvironmentDataDTO envData = new EnvironmentDataDTO();
        envData.setSoilMoisture(new BigDecimal("30"));
        envData.setTemperature(new BigDecimal("25"));
        envData.setHumidity(new BigDecimal("50"));
        envData.setLight(new BigDecimal("30000"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("30"), new BigDecimal("28"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        assertNotNull(plan.getWaterAmountL());
    }

    @Test
    @DisplayName("用水量计算 - 应用学习参数调整")
    void testWaterCalculation_WithLearningAdjustment() {
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("30"), new BigDecimal("25"), new BigDecimal("50"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("30"), new BigDecimal("28"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        // 学习服务调整用水量（减少10%）
        when(learningService.adjustWaterAmount(eq(POINT_ID), any(BigDecimal.class)))
                .thenAnswer(inv -> {
                    BigDecimal amount = inv.getArgument(1);
                    return amount.multiply(new BigDecimal("0.9"));
                });

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        verify(learningService).adjustWaterAmount(eq(POINT_ID), any(BigDecimal.class));
    }

    @Test
    @DisplayName("用水量计算 - 应用作物阶段系数")
    void testWaterCalculation_WithCropStageFactor() {
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("30"), new BigDecimal("25"), new BigDecimal("50"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("30"), new BigDecimal("28"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        // 开花期系数0.7
        IrrigationStrategyDTO strategy = createTomatoStrategy("开花期", new BigDecimal("0.70"));
        strategy.setOptimalHumidity(new BigDecimal("48"));
        when(cropStageService.getStrategy(POINT_ID)).thenReturn(strategy);

        when(cropStageService.adjustWaterByStage(any(BigDecimal.class), any(), any()))
                .thenAnswer(inv -> {
                    BigDecimal water = inv.getArgument(0);
                    BigDecimal factor = strategy.getIrrigationFactor();
                    return water.multiply(factor);
                });

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        assertEquals(new BigDecimal("0.70"), plan.getIrrigationFactor());
    }

    // ========== 执行灌溉测试 ==========

    @Test
    @DisplayName("执行灌溉 - 创建灌溉日志")
    void testExecuteIrrigation_CreatesLog() {
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("35"), new BigDecimal("25"), new BigDecimal("50"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("35"), new BigDecimal("33"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        when(irrigationLogMapper.insert(ArgumentMatchers.<IrrigationLog>any()))
                .thenAnswer(inv -> {
                    IrrigationLog log = inv.getArgument(0);
                    log.setId(1L);
                    return 1;
                });

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);
        IrrigationLog log = smartIrrigationService.executeSmartIrrigation(POINT_ID, plan, envData);

        assertNotNull(log);
        assertEquals(POINT_ID, log.getPointId());
        assertNotNull(log.getStartTime());
        assertEquals(0, log.getMode()); // 自动模式
        verify(irrigationLogMapper).insert(ArgumentMatchers.<IrrigationLog>any());
        verify(decisionMapper).insert(ArgumentMatchers.<SmartIrrigationDecision>any());
    }

    // ========== 灌溉完成回调测试 ==========

    @Test
    @DisplayName("灌溉完成 - 触发学习")
    void testOnIrrigationComplete_TriggersLearning() {
        IrrigationLog log = new IrrigationLog();
        log.setId(1L);
        log.setPointId(POINT_ID);
        log.setSoilMoistureBefore(new BigDecimal("30"));
        log.setWaterAmount(new BigDecimal("10"));

        when(irrigationLogMapper.selectById(1L)).thenReturn(log);

        smartIrrigationService.onIrrigationComplete(1L, new BigDecimal("45"));

        verify(irrigationLogMapper).updateById(ArgumentMatchers.<IrrigationLog>any());
        verify(learningService).learn(any(IrrigationLog.class));
    }

    // ========== 边界条件测试 ==========

    @Test
    @DisplayName("边界条件 - 空环境数据")
    void testBoundary_NullEnvData() {
        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, null, null);

        assertFalse(plan.getShouldIrrigate());
        assertTrue(plan.getReason().contains("缺少"));
    }

    @Test
    @DisplayName("边界条件 - 空土壤湿度")
    void testBoundary_NullSoilMoisture() {
        EnvironmentDataDTO envData = new EnvironmentDataDTO();
        envData.setSoilMoisture(null);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertFalse(plan.getShouldIrrigate());
    }

    @Test
    @DisplayName("边界条件 - 自定义阈值范围")
    void testBoundary_CustomThresholdRange() {
        // 阈值20，非常低
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("25"), new BigDecimal("25"), new BigDecimal("50"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("25"), new BigDecimal("24"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 20)).thenReturn(prediction);

        IrrigationPlanConfig config = new IrrigationPlanConfig();
        config.setMoistureThreshold(20);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, config);

        // 阈值20，当前25，不需要灌溉
        assertFalse(plan.getShouldIrrigate());
    }

    @Test
    @DisplayName("边界条件 - 阈值超出范围自动修正")
    void testBoundary_ThresholdOutOfRange() {
        // 阈值设为80，超出范围
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("50"), new BigDecimal("25"), new BigDecimal("50"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("50"), new BigDecimal("48"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 70)).thenReturn(prediction); // 应该被修正为70

        IrrigationPlanConfig config = new IrrigationPlanConfig();
        config.setMoistureThreshold(80); // 超出范围

        smartIrrigationService.buildSmartPlan(POINT_ID, envData, config);

        // 阈值应该被限制在70
        verify(moisturePredictor).analyze(POINT_ID, 70);
    }

    @Test
    @DisplayName("边界条件 - 灌溉时长范围限制")
    void testBoundary_DurationRange() {
        // 极低湿度，需要大量水
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("20"), new BigDecimal("30"), new BigDecimal("30"));

        MoisturePredictionDTO prediction = createPrediction(new BigDecimal("20"), new BigDecimal("18"), false, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertTrue(plan.getShouldIrrigate());
        assertTrue(plan.getDurationSeconds() >= 10);
        assertTrue(plan.getDurationSeconds() <= 180);
    }

    // ========== 实际场景测试 ==========

    @Test
    @DisplayName("实际场景 - 夏日午后快速蒸发")
    void testScenario_SummerAfternoon() {
        // 夏日午后：温度35度，湿度30%，光照强
        EnvironmentDataDTO envData = new EnvironmentDataDTO();
        envData.setSoilMoisture(new BigDecimal("38"));
        envData.setTemperature(new BigDecimal("35"));
        envData.setHumidity(new BigDecimal("30"));
        envData.setLight(new BigDecimal("35000"));

        // 预测快速下降
        MoisturePredictionDTO prediction = createPrediction(
                new BigDecimal("38"), new BigDecimal("32"), true, "falling");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        // 应该触发预防性灌溉
        assertTrue(plan.getShouldIrrigate());
        assertEquals("predictive", plan.getDecisionType());
    }

    @Test
    @DisplayName("实际场景 - 雨后高湿")
    void testScenario_AfterRain() {
        // 雨后：湿度高，不需要灌溉
        EnvironmentDataDTO envData = createEnvData(new BigDecimal("70"), new BigDecimal("22"), new BigDecimal("85"));

        MoisturePredictionDTO prediction = createPrediction(
                new BigDecimal("70"), new BigDecimal("68"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertFalse(plan.getShouldIrrigate());
    }

    @Test
    @DisplayName("实际场景 - 夜间稳定期")
    void testScenario_NightStable() {
        // 夜间：温度低，湿度稳定
        EnvironmentDataDTO envData = new EnvironmentDataDTO();
        envData.setSoilMoisture(new BigDecimal("50"));
        envData.setTemperature(new BigDecimal("18"));
        envData.setHumidity(new BigDecimal("70"));
        envData.setLight(new BigDecimal("0"));

        MoisturePredictionDTO prediction = createPrediction(
                new BigDecimal("50"), new BigDecimal("49"), false, "stable");
        when(moisturePredictor.analyze(POINT_ID, 40)).thenReturn(prediction);

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(POINT_ID, envData, null);

        assertFalse(plan.getShouldIrrigate());
        assertEquals("standard", plan.getDecisionType());
    }

    // ========== 辅助方法 ==========

    private EnvironmentDataDTO createEnvData(BigDecimal soilMoisture, BigDecimal temperature, BigDecimal humidity) {
        EnvironmentDataDTO env = new EnvironmentDataDTO();
        env.setSoilMoisture(soilMoisture);
        env.setTemperature(temperature);
        env.setHumidity(humidity);
        return env;
    }

    private MoisturePredictionDTO createPrediction(BigDecimal current, BigDecimal predict2h,
                                                     Boolean needPreIrrigation, String trend) {
        MoisturePredictionDTO prediction = new MoisturePredictionDTO();
        prediction.setCurrentMoisture(current);
        prediction.setPredict2h(predict2h);
        prediction.setNeedPreIrrigation(needPreIrrigation);
        prediction.setTrend(trend);
        prediction.setConfidence(new BigDecimal("0.80"));
        prediction.setReason("正常");
        return prediction;
    }

    private IrrigationStrategyDTO createDefaultStrategy() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(false);
        strategy.setIrrigationFactor(BigDecimal.ONE);
        strategy.setOptimalHumidity(new BigDecimal("52"));
        strategy.setMaxHumidity(new BigDecimal("75"));
        return strategy;
    }

    private IrrigationStrategyDTO createTomatoStrategy(String stage, BigDecimal factor) {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(true);
        strategy.setCropType("tomato");
        strategy.setCropName("番茄");
        strategy.setCurrentStage(stage);
        strategy.setIrrigationFactor(factor);
        strategy.setMinHumidity(new BigDecimal("40"));
        strategy.setMaxHumidity(new BigDecimal("55"));
        strategy.setOptimalHumidity(new BigDecimal("48"));
        return strategy;
    }
}
