package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.response.AutoIrrigationPlanResponse;
import com.agriculture.model.request.AutoIrrigationRequest;
import com.agriculture.model.response.AutoIrrigationResultResponse;
import com.agriculture.model.dto.IrrigationDTO;
import com.agriculture.model.request.IrrigationPlanRequest;
import com.agriculture.service.IrrigationService;
import jakarta.validation.Valid;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 灌溉管理接口
 */
@RestController
@RequestMapping("/irrigation")
@RequiredArgsConstructor
@Slf4j
public class IrrigationController {

    private final IrrigationService irrigationService;

    /**
     * 获取灌溉记录
     */
    @GetMapping("/logs")
    public ApiResponse<List<IrrigationDTO>> getLogs(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {
        List<IrrigationDTO> logs = irrigationService.getLogsByPointId(pointId);
        return ApiResponse.success(logs);
    }

    /**
     * 分页获取灌溉记录
     */
    @GetMapping("/logs/paged")
    public ApiResponse<Page<IrrigationDTO>> getLogsPaged(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "10") int size) {
        Page<IrrigationDTO> logs = irrigationService.getLogsPaged(pointId, page, size);
        return ApiResponse.success(logs);
    }

    /**
     * 获取最近灌溉记录
     */
    @GetMapping("/latest")
    public ApiResponse<IrrigationDTO> getLatestLog(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {
        IrrigationDTO log = irrigationService.getLatestLog(pointId);
        if (log == null) {
            return ApiResponse.error("暂无灌溉记录");
        }
        return ApiResponse.success(log);
    }

    /**
     * 获取总灌溉水量
     */
    @GetMapping("/total")
    public ApiResponse<Double> getTotalWaterAmount(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {
        Double total = irrigationService.getTotalWaterAmount(pointId);
        return ApiResponse.success(total != null ? total : 0.0);
    }

    // Compute auto irrigation plan on the backend.
    @PostMapping("/plan")
    public ApiResponse<AutoIrrigationPlanResponse> getAutoPlan(@RequestBody IrrigationPlanRequest request) {
        AutoIrrigationPlanResponse plan = irrigationService.buildAutoPlan(request);
        return ApiResponse.success(plan);
    }

    // Compute plan and start auto irrigation if allowed.
    @PostMapping("/auto/start")
    public ApiResponse<AutoIrrigationResultResponse> startAutoIrrigation(@RequestBody AutoIrrigationRequest request) {
        AutoIrrigationResultResponse result = irrigationService.startAutoIrrigation(request);
        return ApiResponse.success(result);
    }

    /**
     * 开始灌溉
     */
    @PostMapping("/start")
    public ApiResponse<IrrigationDTO> startIrrigation(@Valid @RequestBody IrrigationDTO.StartRequest request) {
        IrrigationDTO log = irrigationService.startIrrigation(request);
        return ApiResponse.success("开始灌溉", log);
    }

    /**
     * 停止灌溉
     */
    @PostMapping("/stop")
    public ApiResponse<IrrigationDTO> stopIrrigation(@Valid @RequestBody IrrigationDTO.StopRequest request) {
        IrrigationDTO log = irrigationService.stopIrrigation(request.getLogId());
        return ApiResponse.success("停止灌溉", log);
    }

    /**
     * 删除灌溉记录
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteLog(@PathVariable Long id) {
        irrigationService.deleteLog(id);
        return ApiResponse.success("删除成功", null);
    }
}
