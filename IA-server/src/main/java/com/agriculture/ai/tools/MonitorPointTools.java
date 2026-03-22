package com.agriculture.ai.tools;

import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.MonitorPointService;
import dev.langchain4j.agent.tool.Tool;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 监控点管理工具类
 * 为 AI 助手提供监控点查询能力
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class MonitorPointTools {

    private final MonitorPointService monitorPointService;

    @Tool("获取系统中所有监控点列表")
    public List<MonitorPointDTO> getAllMonitorPoints() {
        log.info("[AI Tool] 获取所有监控点");
        return monitorPointService.getAllPoints();
    }

    @Tool("获取所有激活状态的监控点")
    public List<MonitorPointDTO> getActiveMonitorPoints() {
        log.info("[AI Tool] 获取激活监控点");
        return monitorPointService.getActivePoints();
    }

    @Tool("根据监控点ID获取详细信息")
    public MonitorPointDTO getMonitorPointById(Long id) {
        log.info("[AI Tool] 获取监控点详情: ID={}", id);
        return monitorPointService.getPointById(id);
    }

    @Tool("根据监控点编号获取详细信息")
    public MonitorPointDTO getMonitorPointByPointId(String pointId) {
        log.info("[AI Tool] 获取监控点详情: pointId={}", pointId);
        return monitorPointService.getPointByPointId(pointId);
    }

    @Tool("生成监控点概览报告，包括各监控点的作物类型和状态")
    public String generateMonitorPointOverview() {
        log.info("[AI Tool] 生成监控点概览报告");
        
        List<MonitorPointDTO> activePoints = monitorPointService.getActivePoints();
        List<MonitorPointDTO> allPoints = monitorPointService.getAllPoints();
        
        StringBuilder report = new StringBuilder();
        report.append("【监控点概览】\n");
        report.append("总监控点数: ").append(allPoints.size()).append("\n");
        report.append("激活监控点数: ").append(activePoints.size()).append("\n\n");
        
        if (activePoints.isEmpty()) {
            report.append("当前无激活的监控点");
            return report.toString();
        }

        report.append("激活监控点列表:\n");
        report.append("------------------------\n");
        
        for (MonitorPointDTO point : activePoints) {
            report.append(String.format("ID: %d | 名称: %s | 位置: %s | 编码: %s\n",
                    point.getId(),
                    point.getPointName(),
                    point.getLocation() != null ? point.getLocation() : "未设置",
                    point.getPointCode() != null ? point.getPointCode() : "未设置"
            ));
        }

        return report.toString();
    }

    @Tool("获取指定农场ID的所有监控点")
    public List<MonitorPointDTO> getPointsByFarmId(Long farmId) {
        log.info("[AI Tool] 获取农场 {} 的监控点", farmId);
        return monitorPointService.getPointsByFarmId(farmId);
    }
}
