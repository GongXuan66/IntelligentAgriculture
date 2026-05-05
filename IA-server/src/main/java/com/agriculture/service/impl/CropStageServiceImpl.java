package com.agriculture.service.impl;

import com.agriculture.entity.CropPlanting;
import com.agriculture.entity.CropStageConfig;
import com.agriculture.mapper.CropPlantingMapper;
import com.agriculture.mapper.CropStageConfigMapper;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import com.agriculture.service.CropStageService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class CropStageServiceImpl implements CropStageService {

    private final CropPlantingMapper cropPlantingMapper;
    private final CropStageConfigMapper stageConfigMapper;

    @Override
    public IrrigationStrategyDTO getStrategy(Long pointId) {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();

        CropPlanting crop = getActiveCropByPointId(pointId);

        if (crop == null) {
            return getDefaultStrategy();
        }

        int daysSincePlanting = calculateDaysSincePlanting(crop.getPlantingDate());

        CropStageConfig stage = getStageConfigByCropCodeAndDay(
                crop.getCropCode(), daysSincePlanting);

        if (stage == null) {
            log.warn("未找到作物阶段配置: cropCode={}, days={}", crop.getCropCode(), daysSincePlanting);
            return getDefaultStrategy();
        }

        strategy.setHasCropConfig(true);
        strategy.setCropCode(crop.getCropCode());
        strategy.setCropName(crop.getCropName());
        strategy.setCurrentStage(stage.getStageName());
        strategy.setDaysSincePlanting(daysSincePlanting);
        strategy.setMinHumidity(stage.getMinHumidity());
        strategy.setMaxHumidity(stage.getMaxHumidity());
        strategy.setOptimalHumidity(stage.getOptimalHumidity());
        strategy.setIrrigationFactor(stage.getIrrigationFactor());
        strategy.setFrequencyHint(stage.getFrequencyHint());
        strategy.setWaterNeeds(stage.getWaterNeeds());
        strategy.setSpecialNotes(stage.getSpecialNotes());

        updateCropStageIfNeeded(crop, stage.getStageCode(), stage.getStageName(), daysSincePlanting);

        return strategy;
    }

    @Override
    public BigDecimal adjustWaterByStage(BigDecimal originalWaterAmount,
                                          IrrigationStrategyDTO strategy,
                                          BigDecimal currentMoisture) {
        if (!strategy.getHasCropConfig()) {
            return originalWaterAmount;
        }

        BigDecimal adjustedWater = originalWaterAmount.multiply(strategy.getIrrigationFactor());

        if (strategy.getMaxHumidity() != null && currentMoisture != null) {
            BigDecimal maxAllowed = strategy.getMaxHumidity();
            if (currentMoisture.compareTo(maxAllowed) >= 0) {
                log.info("当前湿度{}%已达阶段最高限制{}%", currentMoisture, maxAllowed);
                return BigDecimal.ZERO;
            }
        }

        log.debug("调整灌溉量: original={}, factor={}, adjusted={}",
                originalWaterAmount, strategy.getIrrigationFactor(), adjustedWater);

        return adjustedWater;
    }

    @Override
    public List<CropStageConfig> getStageConfigs(String cropCode) {
        LambdaQueryWrapper<CropStageConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(CropStageConfig::getCropCode, cropCode)
               .orderByAsc(CropStageConfig::getStageOrder);
        return stageConfigMapper.selectList(wrapper);
    }

    @Override
    @Transactional
    public void setCrop(Long pointId, String cropCode, String cropName, LocalDate plantingDate) {
        CropPlanting existing = getActiveCropByPointId(pointId);

        if (existing != null) {
            existing.setCropCode(cropCode);
            existing.setCropName(cropName);
            existing.setPlantingDate(plantingDate);
            existing.setCurrentStage(null);
            existing.setStageUpdatedAt(null);
            cropPlantingMapper.updateById(existing);
            log.info("更新作物信息: pointId={}, cropCode={}", pointId, cropCode);
        } else {
            CropPlanting newCrop = new CropPlanting();
            newCrop.setPointId(pointId);
            newCrop.setCropCode(cropCode);
            newCrop.setCropName(cropName);
            newCrop.setPlantingDate(plantingDate);
            newCrop.setStatus(1);
            cropPlantingMapper.insert(newCrop);
            log.info("创建作物信息: pointId={}, cropCode={}", pointId, cropCode);
        }
    }

    @Override
    @Transactional
    public void harvestCrop(Long pointId) {
        CropPlanting crop = getActiveCropByPointId(pointId);
        if (crop != null) {
            crop.setStatus(0);
            cropPlantingMapper.updateById(crop);
            log.info("作物已收获: pointId={}", pointId);
        }
    }

    @Override
    public String[] getSupportedCropCodes() {
        return new String[]{
                "tomato", "cucumber", "pepper", "eggplant",
                "rice", "corn", "vegetable", "strawberry", "watermelon", "cabbage"
        };
    }

    @Override
    public String[] getSupportedCropTypes() {
        return getSupportedCropCodes();
    }

    @Override
    public String getCropName(String cropCode) {
        switch (cropCode) {
            case "tomato": return "番茄";
            case "cucumber": return "黄瓜";
            case "pepper": return "辣椒";
            case "eggplant": return "茄子";
            case "rice": return "水稻";
            case "corn": return "玉米";
            case "vegetable": return "蔬菜";
            case "strawberry": return "草莓";
            case "watermelon": return "西瓜";
            case "cabbage": return "白菜";
            default: return cropCode;
        }
    }

    @Override
    public String getCropTypeName(String cropCode) {
        return getCropName(cropCode);
    }

    private CropPlanting getActiveCropByPointId(Long pointId) {
        LambdaQueryWrapper<CropPlanting> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(CropPlanting::getPointId, pointId)
               .eq(CropPlanting::getStatus, 1);
        return cropPlantingMapper.selectOne(wrapper);
    }

    private CropStageConfig getStageConfigByCropCodeAndDay(String cropCode, int days) {
        LambdaQueryWrapper<CropStageConfig> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(CropStageConfig::getCropCode, cropCode)
               .le(CropStageConfig::getStartDay, days)
               .ge(CropStageConfig::getEndDay, days);
        return stageConfigMapper.selectOne(wrapper);
    }

    private int calculateDaysSincePlanting(LocalDate plantingDate) {
        if (plantingDate == null) return 0;
        return (int) ChronoUnit.DAYS.between(plantingDate, LocalDate.now());
    }

    @Transactional
    protected void updateCropStageIfNeeded(CropPlanting crop, String newStageCode, String newStageName, int currentDay) {
        if (!newStageCode.equals(crop.getCurrentStage())) {
            crop.setCurrentStage(newStageName);
            crop.setCurrentStageDay(currentDay);
            crop.setStageUpdatedAt(LocalDate.now());
            cropPlantingMapper.updateById(crop);
            log.info("更新作物阶段: pointId={}, cropName={}, newStage={}",
                    crop.getPointId(), crop.getCropName(), newStageName);
        }
    }

    private IrrigationStrategyDTO getDefaultStrategy() {
        IrrigationStrategyDTO strategy = new IrrigationStrategyDTO();
        strategy.setHasCropConfig(false);
        strategy.setMinHumidity(new BigDecimal("40"));
        strategy.setMaxHumidity(new BigDecimal("75"));
        strategy.setOptimalHumidity(new BigDecimal("52"));
        strategy.setIrrigationFactor(BigDecimal.ONE);
        strategy.setFrequencyHint("根据环境自动调整");
        return strategy;
    }
}
