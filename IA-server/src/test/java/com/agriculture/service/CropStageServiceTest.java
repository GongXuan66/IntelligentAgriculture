package com.agriculture.service;

import com.agriculture.entity.CropInfo;
import com.agriculture.entity.CropStageConfig;
import com.agriculture.mapper.CropInfoMapper;
import com.agriculture.mapper.CropStageConfigMapper;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;
import org.mockito.ArgumentMatchers;

/**
 * 作物生长阶段服务测试
 */
@ExtendWith(MockitoExtension.class)
class CropStageServiceTest {

    @Mock
    private CropInfoMapper cropInfoMapper;

    @Mock
    private CropStageConfigMapper stageConfigMapper;

    @InjectMocks
    private CropStageService cropStageService;

    private static final Long POINT_ID = 1L;

    // ========== 获取策略测试 ==========

    @Test
    @DisplayName("获取策略 - 无作物配置返回默认策略")
    void testGetStrategy_NoCrop_ReturnsDefault() {
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(null);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        assertNotNull(strategy);
        assertFalse(strategy.getHasCropConfig());
        assertEquals(new BigDecimal("40"), strategy.getMinHumidity());
        assertEquals(new BigDecimal("75"), strategy.getMaxHumidity());
        assertEquals(BigDecimal.ONE, strategy.getIrrigationFactor());
    }

    @Test
    @DisplayName("获取策略 - 番茄播种期策略")
    void testGetStrategy_TomatoSeedlingStage() {
        // 模拟番茄播种3天
        CropInfo crop = createCropInfo("tomato", "番茄", LocalDate.now().minusDays(3));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);

        // 播种期配置 (0-7天)
        CropStageConfig stage = createStageConfig("tomato", "播种期", 0, 7,
                new BigDecimal("60"), new BigDecimal("75"), new BigDecimal("65"),
                new BigDecimal("1.20"), "每天2-3次少量");
        when(stageConfigMapper.findByCropTypeAndDay("tomato", 3)).thenReturn(stage);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        assertTrue(strategy.getHasCropConfig());
        assertEquals("tomato", strategy.getCropType());
        assertEquals("播种期", strategy.getCurrentStage());
        assertEquals(3, strategy.getDaysSincePlanting());
        assertEquals(new BigDecimal("1.20"), strategy.getIrrigationFactor());
        assertEquals(new BigDecimal("65"), strategy.getOptimalHumidity());
    }

    @Test
    @DisplayName("获取策略 - 番茄结果期策略")
    void testGetStrategy_TomatoFruitingStage() {
        // 模拟番茄播种60天
        CropInfo crop = createCropInfo("tomato", "番茄", LocalDate.now().minusDays(60));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);

        // 结果期配置 (50-90天)
        CropStageConfig stage = createStageConfig("tomato", "结果期", 50, 90,
                new BigDecimal("50"), new BigDecimal("70"), new BigDecimal("60"),
                new BigDecimal("1.10"), "每天1-2次");
        when(stageConfigMapper.findByCropTypeAndDay("tomato", 60)).thenReturn(stage);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        assertEquals("结果期", strategy.getCurrentStage());
        assertEquals(new BigDecimal("1.10"), strategy.getIrrigationFactor());
        assertEquals(new BigDecimal("60"), strategy.getOptimalHumidity());
    }

    @Test
    @DisplayName("获取策略 - 番茄开花期（敏感期）策略")
    void testGetStrategy_TomatoFloweringStage() {
        // 模拟番茄播种40天
        CropInfo crop = createCropInfo("tomato", "番茄", LocalDate.now().minusDays(40));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);

        // 开花期配置 (30-50天)
        CropStageConfig stage = createStageConfig("tomato", "开花期", 30, 50,
                new BigDecimal("40"), new BigDecimal("55"), new BigDecimal("48"),
                new BigDecimal("0.70"), "精准控制");
        when(stageConfigMapper.findByCropTypeAndDay("tomato", 40)).thenReturn(stage);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        assertEquals("开花期", strategy.getCurrentStage());
        // 开花期灌溉系数较低
        assertTrue(strategy.getIrrigationFactor().compareTo(BigDecimal.ONE) < 0);
    }

    @Test
    @DisplayName("获取策略 - 水稻特殊需水策略")
    void testGetStrategy_RiceWaterNeeds() {
        // 模拟水稻播种10天（分蘖期）
        CropInfo crop = createCropInfo("rice", "水稻", LocalDate.now().minusDays(10));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);

        // 分蘖期配置
        CropStageConfig stage = createStageConfig("rice", "分蘖期", 10, 40,
                new BigDecimal("70"), new BigDecimal("90"), new BigDecimal("80"),
                new BigDecimal("1.20"), "浅水层");
        when(stageConfigMapper.findByCropTypeAndDay("rice", 10)).thenReturn(stage);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        assertEquals("rice", strategy.getCropType());
        assertEquals("分蘖期", strategy.getCurrentStage());
        // 水稻需要更高湿度
        assertTrue(strategy.getMinHumidity().compareTo(new BigDecimal("70")) >= 0);
    }

    @Test
    @DisplayName("获取策略 - 找不到阶段配置返回默认")
    void testGetStrategy_NoStageConfig_ReturnsDefault() {
        CropInfo crop = createCropInfo("unknown", "未知作物", LocalDate.now().minusDays(30));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);
        when(stageConfigMapper.findByCropTypeAndDay("unknown", 30)).thenReturn(null);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        assertFalse(strategy.getHasCropConfig());
    }

    // ========== 用水量调整测试 ==========

    @Test
    @DisplayName("调整用水量 - 应用灌溉系数")
    void testAdjustWater_ApplyFactor() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(true);
        strategy.setIrrigationFactor(new BigDecimal("1.20"));  // 增加20%

        BigDecimal original = new BigDecimal("10.0");
        BigDecimal adjusted = cropStageService.adjustWaterByStage(original, strategy, new BigDecimal("40"));

        assertEquals(new BigDecimal("12.00"), adjusted);
    }

    @Test
    @DisplayName("调整用水量 - 开花期减少用水")
    void testAdjustWater_FloweringStageReduce() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(true);
        strategy.setIrrigationFactor(new BigDecimal("0.70"));  // 减少30%
        strategy.setMaxHumidity(new BigDecimal("55"));

        BigDecimal original = new BigDecimal("10.0");
        BigDecimal adjusted = cropStageService.adjustWaterByStage(original, strategy, new BigDecimal("45"));

        assertEquals(new BigDecimal("7.00"), adjusted);
    }

    @Test
    @DisplayName("调整用水量 - 已达最高湿度不灌溉")
    void testAdjustWater_MaxHumidityReached_NoIrrigation() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(true);
        strategy.setIrrigationFactor(BigDecimal.ONE);
        strategy.setMaxHumidity(new BigDecimal("55"));

        // 当前湿度已达最高值
        BigDecimal adjusted = cropStageService.adjustWaterByStage(
                new BigDecimal("10.0"), strategy, new BigDecimal("55"));

        assertEquals(BigDecimal.ZERO, adjusted);
    }

    @Test
    @DisplayName("调整用水量 - 超过最高湿度不灌溉")
    void testAdjustWater_ExceedMaxHumidity_NoIrrigation() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(true);
        strategy.setIrrigationFactor(BigDecimal.ONE);
        strategy.setMaxHumidity(new BigDecimal("55"));

        // 当前湿度超过最高值
        BigDecimal adjusted = cropStageService.adjustWaterByStage(
                new BigDecimal("10.0"), strategy, new BigDecimal("58"));

        assertEquals(BigDecimal.ZERO, adjusted);
    }

    @Test
    @DisplayName("调整用水量 - 无作物配置不调整")
    void testAdjustWater_NoCropConfig_NoChange() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(false);

        BigDecimal original = new BigDecimal("10.0");
        BigDecimal adjusted = cropStageService.adjustWaterByStage(original, strategy, new BigDecimal("40"));

        assertEquals(original, adjusted);
    }

    // ========== 设置作物测试 ==========

    @Test
    @DisplayName("设置作物 - 新增作物")
    void testSetCrop_CreateNew() {
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(null);

        cropStageService.setCrop(POINT_ID, "tomato", "番茄", LocalDate.now());

        verify(cropInfoMapper).insert(ArgumentMatchers.<CropInfo>any());
    }

    @Test
    @DisplayName("设置作物 - 更新现有作物")
    void testSetCrop_UpdateExisting() {
        CropInfo existing = new CropInfo();
        existing.setPointId(POINT_ID);
        existing.setCropType("cucumber");
        existing.setCropName("黄瓜");
        existing.setPlantingDate(LocalDate.now().minusDays(10));

        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(existing);

        cropStageService.setCrop(POINT_ID, "tomato", "番茄", LocalDate.now());

        verify(cropInfoMapper).updateById(ArgumentMatchers.<CropInfo>any());
    }

    // ========== 收获作物测试 ==========

    @Test
    @DisplayName("收获作物 - 标记为已完成")
    void testHarvest_MarkAsCompleted() {
        CropInfo crop = new CropInfo();
        crop.setPointId(POINT_ID);
        crop.setStatus(1);

        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);

        cropStageService.harvestCrop(POINT_ID);

        verify(cropInfoMapper).updateById(argThat(c -> c.getStatus() == 0));
    }

    @Test
    @DisplayName("收获作物 - 无作物时不操作")
    void testHarvest_NoCrop_NoAction() {
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(null);

        cropStageService.harvestCrop(POINT_ID);

        verify(cropInfoMapper, never()).updateById(ArgumentMatchers.<CropInfo>any());
    }

    // ========== 作物类型测试 ==========

    @Test
    @DisplayName("获取支持的作物类型")
    void testGetSupportedCropTypes() {
        String[] types = cropStageService.getSupportedCropTypes();

        assertTrue(types.length >= 7);
        assertTrue(Arrays.asList(types).contains("tomato"));
        assertTrue(Arrays.asList(types).contains("rice"));
        assertTrue(Arrays.asList(types).contains("corn"));
    }

    @Test
    @DisplayName("获取作物类型中文名称")
    void testGetCropTypeName() {
        assertEquals("番茄", cropStageService.getCropTypeName("tomato"));
        assertEquals("黄瓜", cropStageService.getCropTypeName("cucumber"));
        assertEquals("水稻", cropStageService.getCropTypeName("rice"));
        assertEquals("玉米", cropStageService.getCropTypeName("corn"));
        assertEquals("unknown", cropStageService.getCropTypeName("unknown"));
    }

    // ========== 阶段配置列表测试 ==========

    @Test
    @DisplayName("获取作物阶段配置列表")
    void testGetStageConfigs() {
        CropStageConfig stage1 = createStageConfig("tomato", "播种期", 0, 7,
                new BigDecimal("60"), new BigDecimal("75"), new BigDecimal("65"),
                BigDecimal.ONE, "test");
        CropStageConfig stage2 = createStageConfig("tomato", "幼苗期", 7, 30,
                new BigDecimal("50"), new BigDecimal("65"), new BigDecimal("55"),
                BigDecimal.ONE, "test");

        when(stageConfigMapper.findByCropType("tomato"))
                .thenReturn(Arrays.asList(stage1, stage2));

        List<CropStageConfig> configs = cropStageService.getStageConfigs("tomato");

        assertEquals(2, configs.size());
    }

    // ========== 边界条件测试 ==========

    @Test
    @DisplayName("边界条件 - 未来播种日期")
    void testBoundary_FuturePlantingDate() {
        // 播种日期在未来
        CropInfo crop = createCropInfo("tomato", "番茄", LocalDate.now().plusDays(5));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);

        CropStageConfig stage = createStageConfig("tomato", "播种期", 0, 7,
                new BigDecimal("60"), new BigDecimal("75"), new BigDecimal("65"),
                BigDecimal.ONE, "test");
        when(stageConfigMapper.findByCropTypeAndDay("tomato", -5)).thenReturn(stage);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        // 负数天数应该被正确处理
        assertNotNull(strategy);
    }

    @Test
    @DisplayName("边界条件 - 超出所有阶段范围")
    void testBoundary_ExceedAllStages() {
        // 播种150天，超出番茄的所有阶段
        CropInfo crop = createCropInfo("tomato", "番茄", LocalDate.now().minusDays(150));
        when(cropInfoMapper.findActiveByPointId(POINT_ID)).thenReturn(crop);
        when(stageConfigMapper.findByCropTypeAndDay("tomato", 150)).thenReturn(null);

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(POINT_ID);

        // 应返回默认策略
        assertFalse(strategy.getHasCropConfig());
    }

    // ========== 辅助方法 ==========

    private CropInfo createCropInfo(String cropType, String cropName, LocalDate plantingDate) {
        CropInfo crop = new CropInfo();
        crop.setPointId(POINT_ID);
        crop.setCropType(cropType);
        crop.setCropName(cropName);
        crop.setPlantingDate(plantingDate);
        crop.setStatus(1);
        return crop;
    }

    private CropStageConfig createStageConfig(String cropType, String stageName,
                                               int startDay, int endDay,
                                               BigDecimal minH, BigDecimal maxH, BigDecimal optimalH,
                                               BigDecimal factor, String frequency) {
        CropStageConfig config = new CropStageConfig();
        config.setCropType(cropType);
        config.setStageName(stageName);
        config.setStartDay(startDay);
        config.setEndDay(endDay);
        config.setMinHumidity(minH);
        config.setMaxHumidity(maxH);
        config.setOptimalHumidity(optimalH);
        config.setIrrigationFactor(factor);
        config.setFrequencyHint(frequency);
        return config;
    }
}
