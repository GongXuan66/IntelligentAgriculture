package com.agriculture.controller;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.entity.IrrigationThresholdConfig;
import com.agriculture.mapper.IrrigationLogMapper;
import com.agriculture.mapper.IrrigationThresholdConfigMapper;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationStrategyDTO;
import com.agriculture.model.dto.MoisturePredictionDTO;
import com.agriculture.model.dto.SmartIrrigationPlanDTO;
import com.agriculture.model.request.IrrigationPlanConfig;
import com.agriculture.model.response.ApiResponse;
import com.agriculture.service.*;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * 测试接口控制器 - 用于开发和测试
 */
@RestController
@RequestMapping("/test")
@RequiredArgsConstructor
@Slf4j
public class TestController {

    private final MockGatewayService mockGatewayService;
    private final MonitorPointService monitorPointService;
    private final DeviceService deviceService;
    private final SensorDataService sensorDataService;
    private final IrrigationService irrigationService;
    private final AlarmService alarmService;

    // 智能灌溉相关服务
    private final MoisturePredictor moisturePredictor;
    private final IrrigationLearningService learningService;
    private final CropStageService cropStageService;
    private final SmartIrrigationService smartIrrigationService;
    private final IrrigationLogMapper irrigationLogMapper;
    private final IrrigationThresholdConfigMapper thresholdConfigMapper;

    // 多目标优化和ONNX服务
    private final MultiObjectiveOptimizer multiObjectiveOptimizer;
    private final ONNXPredictor onnxPredictor;

    /**
     * 测试全部算法效果（一站式测试）
     */
    @GetMapping("/smart-irrigation/all")
    public ApiResponse<Map<String, Object>> testAllAlgorithms(
            @RequestParam(defaultValue = "1") Long pointId) {
        Map<String, Object> result = new HashMap<>();

        // 1. EWMA预测
        MoisturePredictionDTO prediction = moisturePredictor.analyze(pointId, 40);
        result.put("prediction", prediction);

        // 2. 学习进度
        Map<String, Object> learningProgress = learningService.getLearningProgress(pointId);
        result.put("learning", learningProgress);

        // 3. 作物策略
        IrrigationStrategyDTO strategy = cropStageService.getStrategy(pointId);
        result.put("cropStrategy", strategy);

        // 4. 生成完整灌溉计划
        EnvironmentDataDTO envData = getCurrentEnvData(pointId);
        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(pointId, envData, null);
        result.put("irrigationPlan", plan);

        return ApiResponse.success(result);
    }

    /**
     * 测试 EWMA 湿度预测
     */
    @GetMapping("/smart-irrigation/predict")
    public ApiResponse<Map<String, Object>> testPredict(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam(defaultValue = "40") double threshold) {
        Map<String, Object> result = new HashMap<>();

        MoisturePredictionDTO prediction = moisturePredictor.analyze(pointId, threshold);
        result.put("prediction", prediction);
        result.put("algorithm", "EWMA (指数加权移动平均)");
        result.put("description", "基于过去24小时数据预测未来湿度趋势");

        return ApiResponse.success(result);
    }

    /**
     * 测试自适应学习效果
     */
    @GetMapping("/smart-irrigation/learning")
    public ApiResponse<Map<String, Object>> testLearning(
            @RequestParam(defaultValue = "1") Long pointId) {
        Map<String, Object> result = new HashMap<>();

        // 获取学习进度
        Map<String, Object> progress = learningService.getLearningProgress(pointId);
        result.put("progress", progress);

        // 获取学习参数
        Map<String, BigDecimal> params = learningService.getAllLearnedParams(pointId);
        result.put("params", params);

        // 获取阈值配置
        IrrigationThresholdConfig config = learningService.getThresholdConfig(pointId);
        result.put("config", config);

        result.put("description", "系统根据灌溉实际效果自动优化参数");

        return ApiResponse.success(result);
    }

    /**
     * 测试作物生长阶段感知
     */
    @GetMapping("/smart-irrigation/crop")
    public ApiResponse<Map<String, Object>> testCropStage(
            @RequestParam(defaultValue = "1") Long pointId) {
        Map<String, Object> result = new HashMap<>();

        IrrigationStrategyDTO strategy = cropStageService.getStrategy(pointId);
        result.put("strategy", strategy);

        // 获取支持的作物类型
        Map<String, String> cropTypes = new java.util.LinkedHashMap<>();
        for (String code : cropStageService.getSupportedCropCodes()) {
            cropTypes.put(code, cropStageService.getCropName(code));
        }
        result.put("supportedCrops", cropTypes);

        return ApiResponse.success(result);
    }

    /**
     * 设置作物（测试用）
     */
    @PostMapping("/smart-irrigation/crop")
    public ApiResponse<String> setTestCrop(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam String cropCode,
            @RequestParam(defaultValue = "2026-02-01") String plantingDate) {

        String cropName = cropStageService.getCropName(cropCode);
        cropStageService.setCrop(pointId, cropCode, cropName, LocalDate.parse(plantingDate));

        return ApiResponse.success("已设置作物: " + cropName + ", 播种日期: " + plantingDate);
    }

    /**
     * 生成智能灌溉计划
     */
    @PostMapping("/smart-irrigation/plan")
    public ApiResponse<SmartIrrigationPlanDTO> generatePlan(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam(required = false) BigDecimal soilMoisture,
            @RequestParam(required = false) BigDecimal temperature,
            @RequestParam(required = false) Integer threshold) {

        // 构造环境数据
        EnvironmentDataDTO envData = new EnvironmentDataDTO();
        envData.setPointId(pointId);
        envData.setSoilMoisture(soilMoisture != null ? soilMoisture : BigDecimal.valueOf(35));
        envData.setTemperature(temperature != null ? temperature : BigDecimal.valueOf(28));
        envData.setHumidity(BigDecimal.valueOf(55));
        envData.setLight(BigDecimal.valueOf(25000));

        // 配置
        IrrigationPlanConfig config = new IrrigationPlanConfig();
        if (threshold != null) {
            config.setMoistureThreshold(threshold);
        }

        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(pointId, envData, config);
        return ApiResponse.success(plan);
    }

    /**
     * 模拟一次完整的智能灌溉流程
     */
    @PostMapping("/smart-irrigation/simulate")
    public ApiResponse<Map<String, Object>> simulateIrrigation(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam(defaultValue = "35") BigDecimal soilMoistureBefore) {
        Map<String, Object> result = new HashMap<>();

        // 1. 构造环境数据
        EnvironmentDataDTO envData = new EnvironmentDataDTO();
        envData.setPointId(pointId);
        envData.setSoilMoisture(soilMoistureBefore);
        envData.setTemperature(BigDecimal.valueOf(28));
        envData.setHumidity(BigDecimal.valueOf(50));
        envData.setLight(BigDecimal.valueOf(30000));

        // 2. 生成灌溉计划
        SmartIrrigationPlanDTO plan = smartIrrigationService.buildSmartPlan(pointId, envData, null);
        result.put("plan", plan);

        if (!Boolean.TRUE.equals(plan.getShouldIrrigate())) {
            result.put("message", "无需灌溉: " + plan.getReason());
            return ApiResponse.success(result);
        }

        // 3. 执行灌溉
        IrrigationLog log = smartIrrigationService.executeSmartIrrigation(pointId, plan, envData);
        result.put("irrigationLog", log);

        // 4. 模拟灌溉效果（假设每升水提升 1.5% 湿度）
        BigDecimal actualGain = plan.getWaterAmountL().multiply(BigDecimal.valueOf(1.5));
        BigDecimal soilMoistureAfter = soilMoistureBefore.add(actualGain);
        result.put("simulatedMoistureAfter", soilMoistureAfter);

        // 5. 触发学习
        smartIrrigationService.onIrrigationComplete(log.getId(), soilMoistureAfter);

        // 6. 获取更新后的学习参数
        Map<String, Object> newProgress = learningService.getLearningProgress(pointId);
        result.put("updatedLearning", newProgress);

        result.put("message", "灌溉模拟完成，学习参数已更新");

        return ApiResponse.success(result);
    }

    /**
     * 批量生成传感器历史数据（用于预测算法）
     */
    @PostMapping("/smart-irrigation/generate-history")
    public ApiResponse<String> generateHistoryData(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam(defaultValue = "24") int hours,
            @RequestParam(defaultValue = "falling") String trend) {

        Random random = new Random();
        LocalDateTime now = LocalDateTime.now();

        // 基础湿度
        double baseMoisture = 55;
        // 趋势变化率
        double trendRate = "falling".equals(trend) ? -0.5 : ("rising".equals(trend) ? 0.3 : 0);

        for (int i = hours; i >= 0; i--) {
            EnvironmentDataDTO dto = new EnvironmentDataDTO();
            dto.setPointId(pointId);
            dto.setRecordedAt(now.minusHours(i));

            // 按趋势变化的湿度
            double moisture = baseMoisture + (hours - i) * trendRate + (random.nextDouble() - 0.5) * 3;
            moisture = Math.max(20, Math.min(80, moisture));

            dto.setSoilMoisture(BigDecimal.valueOf(moisture).setScale(2, RoundingMode.HALF_UP));
            dto.setTemperature(BigDecimal.valueOf(20 + random.nextDouble() * 12).setScale(2, RoundingMode.HALF_UP));
            dto.setHumidity(BigDecimal.valueOf(45 + random.nextDouble() * 30).setScale(2, RoundingMode.HALF_UP));
            dto.setLight(BigDecimal.valueOf(5000 + random.nextDouble() * 30000).setScale(2, RoundingMode.HALF_UP));
            dto.setCo2(BigDecimal.valueOf(350 + random.nextDouble() * 300).setScale(2, RoundingMode.HALF_UP));

            sensorDataService.saveData(dto);
        }

        return ApiResponse.success("已生成 " + (hours + 1) + " 小时的历史数据，趋势: " + trend);
    }

    /**
     * 查看灌溉历史和学习效果
     */
    @GetMapping("/smart-irrigation/history")
    public ApiResponse<Map<String, Object>> getIrrigationHistory(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam(defaultValue = "10") int limit) {
        Map<String, Object> result = new HashMap<>();

        // 查询灌溉记录
        LambdaQueryWrapper<IrrigationLog> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(IrrigationLog::getPointId, pointId)
               .orderByDesc(IrrigationLog::getStartTime)
               .last("LIMIT " + limit);
        List<IrrigationLog> logs = irrigationLogMapper.selectList(wrapper);
        result.put("irrigationLogs", logs);

        // 统计
        int count = logs.size();
        double totalWater = logs.stream()
                .filter(l -> l.getWaterAmount() != null)
                .mapToDouble(l -> l.getWaterAmount().doubleValue())
                .sum();
        double avgWater = count > 0 ? totalWater / count : 0;

        result.put("stats", Map.of(
            "count", count,
            "totalWater", BigDecimal.valueOf(totalWater).setScale(2, RoundingMode.HALF_UP),
            "avgWater", BigDecimal.valueOf(avgWater).setScale(2, RoundingMode.HALF_UP)
        ));

        return ApiResponse.success(result);
    }

    /**
     * 重置学习参数
     */
    @PostMapping("/smart-irrigation/reset-learning")
    public ApiResponse<String> resetLearning(
            @RequestParam(defaultValue = "1") Long pointId) {

        IrrigationThresholdConfig config = learningService.getThresholdConfig(pointId);
        config.setLearnedMoistureGain(new BigDecimal("1.5000"));
        config.setLearningSampleCount(0);
        config.setLearningConfidence(new BigDecimal("0.00"));
        thresholdConfigMapper.updateById(config);

        return ApiResponse.success("学习参数已重置");
    }

    // ========== 多目标优化测试接口 ==========

    /**
     * 测试多目标优化算法
     */
    @GetMapping("/smart-irrigation/optimization")
    public ApiResponse<Map<String, Object>> testOptimization(
            @RequestParam(defaultValue = "35") double currentMoisture,
            @RequestParam(defaultValue = "55") double targetMoisture,
            @RequestParam(defaultValue = "28") double temperature,
            @RequestParam(defaultValue = "14") int currentHour,
            @RequestParam(defaultValue = "1.0") double cropFactor) {
        
        Map<String, Object> result = new HashMap<>();

        // 执行多目标优化
        MultiObjectiveOptimizer.OptimizationResult optimization = 
                multiObjectiveOptimizer.optimize(currentMoisture, targetMoisture, 
                        temperature, currentHour, cropFactor);

        result.put("optimization", optimization);
        result.put("algorithm", multiObjectiveOptimizer.getAlgorithmInfo());

        return ApiResponse.success(result);
    }

    /**
     * 获取优化算法信息
     */
    @GetMapping("/smart-irrigation/optimization/info")
    public ApiResponse<Map<String, Object>> getOptimizationInfo() {
        return ApiResponse.success(multiObjectiveOptimizer.getAlgorithmInfo());
    }

    // ========== LSTM/ONNX 测试接口 ==========

    /**
     * 测试LSTM模型预测
     */
    @GetMapping("/smart-irrigation/lstm")
    public ApiResponse<Map<String, Object>> testLSTM(
            @RequestParam(defaultValue = "1") Long pointId) {
        
        Map<String, Object> result = new HashMap<>();

        // 获取模型信息
        result.put("modelInfo", onnxPredictor.getModelInfo());

        // 检查模型是否加载
        boolean loaded = onnxPredictor.isModelLoaded();
        result.put("modelLoaded", loaded);

        if (loaded) {
            // 生成测试数据并预测
            java.util.List<float[]> history = generateTestHistory();
            float[] predictions = onnxPredictor.predict(history);

            if (predictions != null) {
                Map<String, Float> predictionResults = new java.util.LinkedHashMap<>();
                predictionResults.put("predict_2h", predictions[0]);
                predictionResults.put("predict_4h", predictions[1]);
                predictionResults.put("predict_6h", predictions[2]);
                result.put("predictions", predictionResults);
            }
        } else {
            result.put("message", "LSTM模型未加载，请先运行训练脚本: python ml-models/train_lstm.py");
        }

        return ApiResponse.success(result);
    }

    /**
     * 获取算法对比报告
     */
    @GetMapping("/smart-irrigation/compare")
    public ApiResponse<Map<String, Object>> compareAlgorithms(
            @RequestParam(defaultValue = "35") double currentMoisture,
            @RequestParam(defaultValue = "55") double targetMoisture) {
        
        Map<String, Object> result = new HashMap<>();

        // 1. EWMA预测
        Map<String, Object> ewmaResult = new HashMap<>();
        ewmaResult.put("name", "EWMA 指数加权移动平均");
        ewmaResult.put("description", "基于历史趋势的简单预测，计算量小");
        ewmaResult.put("status", "已实现");
        result.put("ewma", ewmaResult);

        // 2. 多目标优化
        MultiObjectiveOptimizer.OptimizationResult optimization = 
                multiObjectiveOptimizer.optimize(currentMoisture, targetMoisture, 25, 14, 1.0);
        Map<String, Object> optimResult = new HashMap<>();
        optimResult.put("name", "NSGA-II 多目标遗传算法");
        optimResult.put("description", "在节水、成本、健康间寻找帕累托最优");
        optimResult.put("status", "已实现");
        optimResult.put("result", optimization);
        result.put("multiObjective", optimResult);

        // 3. LSTM深度学习
        Map<String, Object> lstmResult = new HashMap<>();
        lstmResult.put("name", "LSTM 深度学习");
        lstmResult.put("description", "基于神经网络的时序预测");
        lstmResult.put("modelLoaded", onnxPredictor.isModelLoaded());
        lstmResult.put("status", onnxPredictor.isModelLoaded() ? "已部署" : "待训练");
        result.put("lstm", lstmResult);

        return ApiResponse.success(result);
    }

    /**
     * 生成测试历史数据
     */
    private java.util.List<float[]> generateTestHistory() {
        java.util.List<float[]> history = new java.util.ArrayList<>();
        Random random = new Random();
        
        for (int i = 0; i < 24; i++) {
            float moisture = 50 + (i - 12) * 0.8f + random.nextFloat() * 3;
            float temp = 20 + 5 * (float) Math.sin(2 * Math.PI * i / 24);
            float light = (i >= 6 && i <= 18) ? 20000 + random.nextFloat() * 10000 : 100;
            float humidity = 60 - temp * 0.3f + random.nextFloat() * 10;
            float hour = i;
            
            history.add(new float[]{moisture, temp, light, humidity, hour});
        }
        
        return history;
    }

    // ========== 原有测试接口 ==========

    /**
     * 获取系统状态
     */
    @GetMapping("/status")
    public ApiResponse<Map<String, Object>> getStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("mockEnabled", mockGatewayService.isEnabled());
        status.put("pointsCount", monitorPointService.getAllPoints().size());
        status.put("devicesCount", deviceService.getAllDevices().size());
        status.put("unprocessedAlarms", alarmService.getUnprocessedCount());
        return ApiResponse.success(status);
    }

    /**
     * Ping 测试
     */
    @GetMapping("/ping")
    public ApiResponse<String> ping() {
        return ApiResponse.success("pong");
    }

    // ========== 私有方法 ==========

    private EnvironmentDataDTO getCurrentEnvData(Long pointId) {
        EnvironmentDataDTO dto = new EnvironmentDataDTO();
        dto.setPointId(pointId);
        dto.setSoilMoisture(BigDecimal.valueOf(45));
        dto.setTemperature(BigDecimal.valueOf(25));
        dto.setHumidity(BigDecimal.valueOf(55));
        dto.setLight(BigDecimal.valueOf(20000));
        return dto;
    }
}