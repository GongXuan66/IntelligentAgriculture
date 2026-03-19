package com.agriculture.ai.tools;

import com.agriculture.model.dto.IrrigationDTO;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.response.AutoIrrigationPlanResponse;
import com.agriculture.model.request.IrrigationPlanRequest;
import com.agriculture.service.IrrigationService;
import com.agriculture.service.SensorDataService;
import dev.langchain4j.agent.tool.Tool;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 灌溉控制工具类
 * 为 AI 助手提供灌溉控制和查询能力
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class IrrigationTools {

    private final IrrigationService irrigationService;
    private final SensorDataService sensorDataService;

    @Tool("开始灌溉操作。pointId为检测点ID，duration为灌溉时长（秒），mode为模式（0-自动，1-手动）")
    public IrrigationDTO startIrrigation(Long pointId, Integer duration, Integer mode) {
        log.info("[AI Tool] 开始灌溉: 检测点={}, 时长={}秒, 模式={}", pointId, duration, mode);
        
        IrrigationDTO.StartRequest request = new IrrigationDTO.StartRequest();
        request.setPointId(pointId);
        request.setDuration(duration != null ? duration : 60);
        request.setMode(mode != null ? mode : 1);
        
        return irrigationService.startIrrigation(request);
    }

    @Tool("停止正在进行的灌溉任务。logId为灌溉记录ID")
    public IrrigationDTO stopIrrigation(Long logId) {
        log.info("[AI Tool] 停止灌溉: 记录ID={}", logId);
        return irrigationService.stopIrrigation(logId);
    }

    @Tool("获取指定检测点的灌溉历史记录")
    public List<IrrigationDTO> getIrrigationHistory(Long pointId) {
        log.info("[AI Tool] 获取检测点 {} 的灌溉历史", pointId);
        return irrigationService.getLogsByPointId(pointId);
    }

    @Tool("获取指定检测点最近一次灌溉记录")
    public IrrigationDTO getLatestIrrigation(Long pointId) {
        log.info("[AI Tool] 获取检测点 {} 最近灌溉记录", pointId);
        return irrigationService.getLatestLog(pointId);
    }

    @Tool("获取指定检测点的总灌溉用水量（升）")
    public Double getTotalWaterAmount(Long pointId) {
        log.info("[AI Tool] 获取检测点 {} 总用水量", pointId);
        return irrigationService.getTotalWaterAmount(pointId);
    }

    @Tool("根据当前环境数据生成智能灌溉计划建议，返回建议的灌溉时长和用水量")
    public AutoIrrigationPlanResponse getIrrigationPlan(Long pointId) {
        log.info("[AI Tool] 生成检测点 {} 的智能灌溉计划", pointId);
        
        EnvironmentDataDTO envData = sensorDataService.getCurrentData(pointId);
        
        IrrigationPlanRequest request = new IrrigationPlanRequest();
        request.setPointId(pointId);
        request.setEnvData(envData);
        
        return irrigationService.buildAutoPlan(request);
    }

    @Tool("检查当前环境是否需要灌溉，并返回灌溉建议")
    public String checkIrrigationNeed(Long pointId) {
        log.info("[AI Tool] 检查检测点 {} 是否需要灌溉", pointId);
        
        EnvironmentDataDTO envData = sensorDataService.getCurrentData(pointId);
        if (envData == null) {
            return "无法获取检测点 " + pointId + " 的环境数据";
        }

        IrrigationPlanRequest request = new IrrigationPlanRequest();
        request.setPointId(pointId);
        request.setEnvData(envData);
        AutoIrrigationPlanResponse plan = irrigationService.buildAutoPlan(request);

        StringBuilder result = new StringBuilder();
        result.append("【灌溉建议】\n");
        result.append("检测点ID: ").append(pointId).append("\n");
        result.append("当前土壤湿度: ").append(envData.getSoilMoisture()).append("%\n");
        
        if (plan.isShouldIrrigate()) {
            result.append("建议操作: ✅ 需要灌溉\n");
            result.append("建议时长: ").append(plan.getDurationSeconds()).append(" 秒\n");
            result.append("预计用水: ").append(plan.getWaterAmountL()).append(" 升\n");
            result.append("目标湿度: ").append(plan.getTargetMoisture()).append("%\n");
            result.append("风险系数: ").append(plan.getRiskFactor()).append("\n");
        } else {
            result.append("建议操作: ❌ 暂不需要灌溉\n");
            result.append("原因: ").append(plan.getReason()).append("\n");
        }

        return result.toString();
    }
}
