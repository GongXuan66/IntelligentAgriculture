package com.agriculture.ai.tools;

import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.service.SensorDataService;
import dev.langchain4j.agent.tool.Tool;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 环境数据查询工具类
 * 为 AI 助手提供传感器数据和环境监测能力
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class EnvironmentTools {

    private final SensorDataService sensorDataService;

    @Tool("获取指定检测点的当前环境数据，包括温度、湿度、光照、CO2浓度、土壤湿度等")
    public EnvironmentDataDTO getCurrentEnvironment(Long pointId) {
        log.info("[AI Tool] 获取检测点 {} 的当前环境数据", pointId);
        return sensorDataService.getCurrentData(pointId);
    }

    @Tool("获取指定检测点的历史环境数据，limit参数指定返回记录数量，最多100条")
    public List<EnvironmentDataDTO> getHistoryEnvironment(Long pointId, Integer limit) {
        int actualLimit = limit != null ? Math.min(limit, 100) : 10;
        log.info("[AI Tool] 获取检测点 {} 的历史环境数据，数量: {}", pointId, actualLimit);
        return sensorDataService.getHistoryData(pointId, actualLimit);
    }

    @Tool("分析当前环境状况并返回简要报告，包括温度、湿度、光照、土壤湿度是否正常")
    public String analyzeEnvironmentStatus(Long pointId) {
        log.info("[AI Tool] 分析检测点 {} 的环境状况", pointId);
        
        EnvironmentDataDTO data = sensorDataService.getCurrentData(pointId);
        if (data == null) {
            return "无法获取检测点 " + pointId + " 的环境数据";
        }

        StringBuilder report = new StringBuilder();
        report.append("【检测点 ").append(pointId).append(" 环境分析报告】\n");
        
        // 温度分析
        if (data.getTemperature() != null) {
            double temp = data.getTemperature().doubleValue();
            report.append("温度: ").append(temp).append("°C - ");
            if (temp < 10) {
                report.append("⚠️ 过低，建议采取保温措施\n");
            } else if (temp > 35) {
                report.append("⚠️ 过高，建议通风降温\n");
            } else {
                report.append("✅ 正常\n");
            }
        }

        // 湿度分析
        if (data.getHumidity() != null) {
            double humidity = data.getHumidity().doubleValue();
            report.append("湿度: ").append(humidity).append("% - ");
            if (humidity < 30) {
                report.append("⚠️ 过低，空气干燥\n");
            } else if (humidity > 80) {
                report.append("⚠️ 过高，注意通风除湿\n");
            } else {
                report.append("✅ 正常\n");
            }
        }

        // 光照分析
        if (data.getLight() != null) {
            double light = data.getLight().doubleValue();
            report.append("光照: ").append(light).append(" lux - ");
            if (light < 300) {
                report.append("⚠️ 光照不足\n");
            } else {
                report.append("✅ 正常\n");
            }
        }

        // CO2分析
        if (data.getCo2() != null) {
            double co2 = data.getCo2().doubleValue();
            report.append("CO2: ").append(co2).append(" ppm - ");
            if (co2 > 1000) {
                report.append("⚠️ 浓度过高，建议通风\n");
            } else {
                report.append("✅ 正常\n");
            }
        }

        // 土壤湿度分析
        if (data.getSoilMoisture() != null) {
            double soilMoisture = data.getSoilMoisture().doubleValue();
            report.append("土壤湿度: ").append(soilMoisture).append("% - ");
            if (soilMoisture < 40) {
                report.append("⚠️ 土壤干燥，建议灌溉\n");
            } else {
                report.append("✅ 正常\n");
            }
        }

        return report.toString();
    }
}
