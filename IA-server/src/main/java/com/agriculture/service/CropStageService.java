package com.agriculture.service;

import com.agriculture.entity.CropStageConfig;
import com.agriculture.model.dto.IrrigationStrategyDTO;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public interface CropStageService {

    IrrigationStrategyDTO getStrategy(Long pointId);

    BigDecimal adjustWaterByStage(BigDecimal originalWaterAmount, IrrigationStrategyDTO strategy, BigDecimal currentMoisture);

    List<CropStageConfig> getStageConfigs(String cropCode);

    void setCrop(Long pointId, String cropCode, String cropName, LocalDate plantingDate);

    void harvestCrop(Long pointId);

    String[] getSupportedCropCodes();

    String[] getSupportedCropTypes();

    String getCropName(String cropCode);

    String getCropTypeName(String cropCode);
}
