package com.agriculture.controller;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import com.agriculture.model.dto.MoisturePredictionDTO;
import com.agriculture.model.dto.SmartIrrigationPlanDTO;
import com.agriculture.model.request.IrrigationPlanConfig;
import com.agriculture.model.response.ApiResponse;
import com.agriculture.service.CropStageService;
import com.agriculture.service.IrrigationLearningService;
import com.agriculture.service.MoisturePredictor;
import com.agriculture.service.SmartIrrigationService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;
import java.util.Map;

/**
 * 智能灌溉管理接口
 * 提供预测性灌溉、自适应学习、作物生长阶段感知等功能
 */
@RestController
@RequestMapping("/smart-irrigation")
@RequiredArgsConstructor
@Slf4j
public class SmartIrrigationController {

    private final SmartIrrigationService smartIrrigationService;
    private final MoisturePredictor moisturePredictor;
    private final IrrigationLearningService learningService;
    private final CropStageService cropStageService;

    /**
     * 获取智能灌溉计划
     * 综合预测、学习、作物阶段生成最优灌溉方案
     */
    @PostMapping("/plan")
    public ApiResponse<SmartIrrigationPlanDTO> getSmartPlan(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestBody(required = false) SmartPlanRequest request) {

        EnvironmentDataDTO envData = request != null ? request.getEnvData() : null;
        IrrigationPlanConfig config = request != null ? request.getConfig() : null;

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(pointId, envData, config);
        return ApiResponse.success(plan);
    }

    /**
     * 执行智能灌溉
     */
    @PostMapping("/execute")
    public ApiResponse<IrrigationLog> executeSmartIrrigation(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestBody SmartPlanRequest request) {

        EnvironmentDataDTO envData = request != null ? request.getEnvData() : null;
        IrrigationPlanConfig config = request != null ? request.getConfig() : null;

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(pointId, envData, config);

        if (!Boolean.TRUE.equals(plan.getShouldIrrigate())) {
            return ApiResponse.error(plan.getReason());
        }

        IrrigationLog log = smartIrrigationService.executeSmartIrrigation(pointId, plan, envData);
        return ApiResponse.success("智能灌溉已启动", log);
    }

    /**
     * 灌溉完成回调
     * 记录实际效果，触发学习
     */
    @PostMapping("/complete/{logId}")
    public ApiResponse<Void> onIrrigationComplete(
            @PathVariable Long logId,
            @RequestParam BigDecimal soilMoistureAfter) {

        smartIrrigationService.onIrrigationComplete(logId, soilMoistureAfter);
        return ApiResponse.success("灌溉完成并已学习", null);
    }

    // ========== 预测相关接口 ==========

    /**
     * 获取湿度预测
     */
    @GetMapping("/predict")
    public ApiResponse<MoisturePredictionDTO> predictMoisture(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestParam(required = false, defaultValue = "4") int hoursAhead) {

        MoisturePredictionDTO prediction = moisturePredictor.predict(pointId, hoursAhead);
        return ApiResponse.success(prediction);
    }

    /**
     * 分析是否需要预防性灌溉
     */
    @GetMapping("/predict/analyze")
    public ApiResponse<MoisturePredictionDTO> analyzePrediction(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestParam(required = false, defaultValue = "40") double threshold) {

        MoisturePredictionDTO analysis = moisturePredictor.analyze(pointId, threshold);
        return ApiResponse.success(analysis);
    }

    // ========== 学习相关接口 ==========

    /**
     * 获取学习进度
     */
    @GetMapping("/learning/progress")
    public ApiResponse<Map<String, Object>> getLearningProgress(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {

        Map<String, Object> progress = learningService.getLearningProgress(pointId);
        return ApiResponse.success(progress);
    }

    /**
     * 获取学习到的参数
     */
    @GetMapping("/learning/params")
    public ApiResponse<Map<String, BigDecimal>> getLearnedParams(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {

        Map<String, BigDecimal> params = learningService.getAllLearnedParams(pointId);
        return ApiResponse.success(params);
    }

    // ========== 作物阶段相关接口 ==========

    /**
     * 获取当前灌溉策略
     */
    @GetMapping("/strategy")
    public ApiResponse<IrrigationStrategyDTO> getIrrigationStrategy(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(pointId);
        return ApiResponse.success(strategy);
    }

    /**
     * 设置作物信息
     */
    @PostMapping("/crop")
    public ApiResponse<Void> setCrop(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestBody SetCropRequest request) {

        cropStageService.setCrop(
                pointId,
                request.getCropType(),
                request.getCropName(),
                request.getPlantingDate()
        );
        return ApiResponse.success("作物信息已设置", null);
    }

    /**
     * 收获作物
     */
    @DeleteMapping("/crop")
    public ApiResponse<Void> harvestCrop(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {

        cropStageService.harvestCrop(pointId);
        return ApiResponse.success("作物已收获", null);
    }

    /**
     * 获取作物阶段配置
     */
    @GetMapping("/crop/stages")
    public ApiResponse<List<?>> getCropStageConfigs(
            @RequestParam String cropType) {

        return ApiResponse.success(cropStageService.getStageConfigs(cropType));
    }

    /**
     * 获取支持的作物类型
     */
    @GetMapping("/crop/types")
    public ApiResponse<Map<String, String>> getSupportedCropTypes() {
        String[] types = cropStageService.getSupportedCropTypes();
        Map<String, String> result = new java.util.LinkedHashMap<>();
        for (String type : types) {
            result.put(type, cropStageService.getCropTypeName(type));
        }
        return ApiResponse.success(result);
    }

    // ========== 统计接口 ==========

    /**
     * 获取智能灌溉统计
     */
    @GetMapping("/stats")
    public ApiResponse<SmartIrrigationService.SmartIrrigationStats> getStats(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {

        SmartIrrigationService.SmartIrrigationStats stats = smartIrrigationService.getStats(pointId);
        return ApiResponse.success(stats);
    }

    // ========== 请求模型 ==========

    @lombok.Data
    public static class SmartPlanRequest {
        private EnvironmentDataDTO envData;
        private IrrigationPlanConfig config;
    }

    @lombok.Data
    public static class SetCropRequest {
        private String cropType;
        private String cropName;
        private LocalDate plantingDate;
    }
}
