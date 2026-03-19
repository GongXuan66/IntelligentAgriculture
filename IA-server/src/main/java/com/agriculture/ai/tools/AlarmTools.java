package com.agriculture.ai.tools;

import com.agriculture.model.dto.AlarmDTO;
import com.agriculture.service.AlarmService;
import dev.langchain4j.agent.tool.Tool;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 报警管理工具类
 * 为 AI 助手提供报警查询和处理能力
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class AlarmTools {

    private final AlarmService alarmService;

    @Tool("获取所有未处理的报警记录")
    public List<AlarmDTO> getUnprocessedAlarms() {
        log.info("[AI Tool] 获取所有未处理报警");
        return alarmService.getUnprocessedAlarms();
    }

    @Tool("获取指定检测点的所有报警记录")
    public List<AlarmDTO> getAlarmsByPointId(Long pointId) {
        log.info("[AI Tool] 获取检测点 {} 的报警记录", pointId);
        return alarmService.getAlarmsByPointId(pointId);
    }

    @Tool("获取未处理报警的数量")
    public Long getUnprocessedAlarmCount() {
        log.info("[AI Tool] 获取未处理报警数量");
        return alarmService.getUnprocessedCount();
    }

    @Tool("处理指定ID的报警。remark为处理备注（可选）")
    public AlarmDTO handleAlarm(Long alarmId, String remark) {
        log.info("[AI Tool] 处理报警: ID={}, 备注={}", alarmId, remark);
        return alarmService.handleAlarm(alarmId, remark);
    }

    @Tool("处理指定检测点的所有未处理报警")
    public String handleAllAlarmsByPointId(Long pointId) {
        log.info("[AI Tool] 处理检测点 {} 的所有报警", pointId);
        try {
            alarmService.handleAllByPointId(pointId);
            return "已处理检测点 " + pointId + " 的所有未处理报警";
        } catch (Exception e) {
            return "处理失败: " + e.getMessage();
        }
    }

    @Tool("获取报警详情")
    public AlarmDTO getAlarmDetail(Long alarmId) {
        log.info("[AI Tool] 获取报警详情: ID={}", alarmId);
        return alarmService.getAlarmById(alarmId);
    }

    @Tool("生成报警摘要报告，包括各类型报警数量和紧急程度")
    public String generateAlarmReport() {
        log.info("[AI Tool] 生成报警摘要报告");
        
        List<AlarmDTO> unprocessedAlarms = alarmService.getUnprocessedAlarms();
        long totalCount = unprocessedAlarms.size();
        
        if (totalCount == 0) {
            return "【报警状态】✅ 当前无未处理报警，系统运行正常";
        }

        StringBuilder report = new StringBuilder();
        report.append("【报警摘要报告】\n");
        report.append("未处理报警总数: ").append(totalCount).append(" 条\n\n");

        // 按类型统计
        long tempHigh = unprocessedAlarms.stream()
                .filter(a -> "TEMPERATURE_HIGH".equals(a.getAlarmType())).count();
        long tempLow = unprocessedAlarms.stream()
                .filter(a -> "TEMPERATURE_LOW".equals(a.getAlarmType())).count();
        long humidityHigh = unprocessedAlarms.stream()
                .filter(a -> "HUMIDITY_HIGH".equals(a.getAlarmType())).count();
        long humidityLow = unprocessedAlarms.stream()
                .filter(a -> "HUMIDITY_LOW".equals(a.getAlarmType())).count();
        long soilLow = unprocessedAlarms.stream()
                .filter(a -> "SOIL_MOISTURE_LOW".equals(a.getAlarmType())).count();
        long lightLow = unprocessedAlarms.stream()
                .filter(a -> "LIGHT_LOW".equals(a.getAlarmType())).count();
        long co2High = unprocessedAlarms.stream()
                .filter(a -> "CO2_HIGH".equals(a.getAlarmType())).count();

        if (tempHigh > 0) {
            report.append("🔥 高温报警: ").append(tempHigh).append(" 条\n");
        }
        if (tempLow > 0) {
            report.append("❄️ 低温报警: ").append(tempLow).append(" 条\n");
        }
        if (humidityHigh > 0) {
            report.append("💧 湿度过高: ").append(humidityHigh).append(" 条\n");
        }
        if (humidityLow > 0) {
            report.append("🏜️ 湿度过低: ").append(humidityLow).append(" 条\n");
        }
        if (soilLow > 0) {
            report.append("🌱 土壤干燥: ").append(soilLow).append(" 条 - 建议立即灌溉\n");
        }
        if (lightLow > 0) {
            report.append("☀️ 光照不足: ").append(lightLow).append(" 条\n");
        }
        if (co2High > 0) {
            report.append("💨 CO2超标: ").append(co2High).append(" 条 - 建议通风\n");
        }

        // 优先级建议
        report.append("\n【处理建议】\n");
        if (soilLow > 0 || tempHigh > 0) {
            report.append("⚠️ 高优先级: 存在土壤干燥或高温报警，建议优先处理\n");
        }

        return report.toString();
    }
}
