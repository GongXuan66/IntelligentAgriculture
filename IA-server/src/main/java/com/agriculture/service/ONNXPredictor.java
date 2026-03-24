package com.agriculture.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import java.io.File;
import java.nio.FloatBuffer;
import java.util.ArrayList;
import java.util.List;

/**
 * ONNX模型推理服务
 * 使用LSTM模型进行土壤湿度预测
 * 
 * 使用前需要添加Maven依赖:
 * <dependency>
 *     <groupId>com.microsoft.onnxruntime</groupId>
 *     <artifactId>onnxruntime</artifactId>
 *     <version>1.15.1</version>
 * </dependency>
 */
@Slf4j
@Service
public class ONNXPredictor {

    @Value("${irrigation.prediction.mode:ewma}")
    private String predictionMode;

    @Value("${irrigation.prediction.model-path:models/moisture_lstm.onnx}")
    private String modelPath;

    private boolean modelLoaded = false;
    private Object session; // OrtSession (使用Object避免编译错误)
    private Object env;     // OrtEnvironment

    // 模型参数
    private static final int SEQ_LENGTH = 24;
    private static final int FEATURE_SIZE = 5;

    // 归一化参数（需要与训练时一致）
    private float moistureMin = 20f;
    private float moistureMax = 85f;
    private float tempMin = 15f;
    private float tempMax = 40f;
    private float lightMin = 0f;
    private float lightMax = 50000f;
    private float humidityMin = 30f;
    private float humidityMax = 95f;

    @PostConstruct
    public void init() {
        if (!"lstm".equals(predictionMode)) {
            log.info("预测模式为EWMA，跳过ONNX模型加载");
            return;
        }

        try {
            loadModel();
        } catch (Exception e) {
            log.warn("ONNX模型加载失败，将使用EWMA作为后备: {}", e.getMessage());
            predictionMode = "ewma";
        }
    }

    /**
     * 加载ONNX模型
     */
    private void loadModel() {
        try {
            // 检查模型文件
            File modelFile = new File(modelPath);
            if (!modelFile.exists()) {
                // 尝试相对路径
                modelFile = new File("ml-models/moisture_lstm.onnx");
            }

            if (!modelFile.exists()) {
                throw new RuntimeException("ONNX模型文件不存在: " + modelPath);
            }

            // 使用反射加载ONNX Runtime，避免强制依赖
            Class<?> envClass = Class.forName("ai.onnxruntime.OrtEnvironment");
            Class<?> sessionClass = Class.forName("ai.onnxruntime.OrtSession");

            // OrtEnvironment.getEnvironment()
            var getEnvMethod = envClass.getMethod("getEnvironment");
            this.env = getEnvMethod.invoke(null);

            // env.createSession(modelPath)
            var createSessionMethod = envClass.getMethod("createSession", String.class);
            this.session = createSessionMethod.invoke(this.env, modelFile.getAbsolutePath());

            this.modelLoaded = true;
            log.info("ONNX模型加载成功: {}", modelFile.getAbsolutePath());

        } catch (ClassNotFoundException e) {
            throw new RuntimeException("ONNX Runtime未安装，请添加依赖: onnxruntime");
        } catch (Exception e) {
            throw new RuntimeException("加载ONNX模型失败: " + e.getMessage(), e);
        }
    }

    /**
     * 使用LSTM模型预测未来湿度
     * 
     * @param history 历史数据列表，每条包含[湿度, 温度, 光照, 空气湿度, 小时]
     * @return 预测结果 [未来2h, 未来4h, 未来6h]的湿度值
     */
    public float[] predict(List<float[]> history) {
        if (!modelLoaded || session == null) {
            log.warn("ONNX模型未加载，返回空预测");
            return null;
        }

        if (history == null || history.size() < SEQ_LENGTH) {
            log.warn("历史数据不足，需要至少{}条记录", SEQ_LENGTH);
            return null;
        }

        try {
            // 准备输入数据
            float[][][] inputData = prepareInput(history);

            // 执行推理
            return runInference(inputData);

        } catch (Exception e) {
            log.error("ONNX推理失败: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 准备模型输入
     */
    private float[][][] prepareInput(List<float[]> history) {
        float[][][] input = new float[1][SEQ_LENGTH][FEATURE_SIZE];

        // 取最近SEQ_LENGTH条数据
        int startIdx = Math.max(0, history.size() - SEQ_LENGTH);

        for (int i = 0; i < SEQ_LENGTH; i++) {
            int dataIdx = startIdx + i;
            if (dataIdx < history.size()) {
                float[] record = history.get(dataIdx);
                // 归一化
                input[0][i][0] = normalize(record[0], moistureMin, moistureMax);   // 湿度
                input[0][i][1] = normalize(record[1], tempMin, tempMax);            // 温度
                input[0][i][2] = normalize(record[2], lightMin, lightMax);          // 光照
                input[0][i][3] = normalize(record[3], humidityMin, humidityMax);    // 空气湿度
                input[0][i][4] = record[4] / 24f;  // 小时特征
            }
        }

        return input;
    }

    /**
     * 执行ONNX推理
     */
    private float[] runInference(float[][][] inputData) {
        try {
            // 使用反射调用ONNX Runtime API
            Class<?> tensorClass = Class.forName("ai.onnxruntime.OnnxTensor");
            Class<?> envClass = Class.forName("ai.onnxruntime.OrtEnvironment");

            // 创建输入张量
            var createTensorMethod = tensorClass.getMethod("createTensor", envClass, float[][][].class);
            Object inputTensor = createTensorMethod.invoke(null, env, inputData);

            // 创建输入Map
            java.util.Map<String, Object> inputMap = new java.util.HashMap<>();
            inputMap.put("input", inputTensor);

            // 运行推理
            var runMethod = session.getClass().getMethod("run", java.util.Map.class);
            Object result = runMethod.invoke(session, inputMap);

            // 获取输出
            var getMethod = result.getClass().getMethod("get", int.class);
            Object output = getMethod.invoke(result, 0);

            // 获取输出值
            var getValueMethod = output.getClass().getMethod("getValue");
            float[][] outputArray = (float[][]) getValueMethod.invoke(output);

            // 反归一化
            float[] predictions = new float[outputArray[0].length];
            for (int i = 0; i < predictions.length; i++) {
                predictions[i] = denormalize(outputArray[0][i], moistureMin, moistureMax);
            }

            return predictions;

        } catch (Exception e) {
            log.error("ONNX推理执行失败: {}", e.getMessage());
            return null;
        }
    }

    /**
     * 归一化
     */
    private float normalize(float value, float min, float max) {
        return (value - min) / (max - min);
    }

    /**
     * 反归一化
     */
    private float denormalize(float value, float min, float max) {
        return value * (max - min) + min;
    }

    /**
     * 检查模型是否已加载
     */
    public boolean isModelLoaded() {
        return modelLoaded;
    }

    /**
     * 获取当前预测模式
     */
    public String getPredictionMode() {
        return predictionMode;
    }

    /**
     * 获取模型信息
     */
    public java.util.Map<String, Object> getModelInfo() {
        java.util.Map<String, Object> info = new java.util.LinkedHashMap<>();
        info.put("mode", predictionMode);
        info.put("modelLoaded", modelLoaded);
        info.put("modelPath", modelPath);
        info.put("seqLength", SEQ_LENGTH);
        info.put("featureSize", FEATURE_SIZE);
        info.put("predictHours", new int[]{2, 4, 6});
        return info;
    }

    @PreDestroy
    public void cleanup() {
        try {
            if (session != null) {
                var closeMethod = session.getClass().getMethod("close");
                closeMethod.invoke(session);
            }
            log.info("ONNX资源已释放");
        } catch (Exception e) {
            log.warn("释放ONNX资源时出错: {}", e.getMessage());
        }
    }
}
