package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.service.SensorDataService;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

/**
 * 环境数据接口
 */
@RestController
@RequestMapping("/environment")
@RequiredArgsConstructor
@Slf4j
public class EnvironmentController {

    private final SensorDataService sensorDataService;

    /**
     * 获取当前环境数据
     */
    @GetMapping
    public ApiResponse<EnvironmentDataDTO> getCurrentData(
            @RequestParam(required = false, defaultValue = "1") Long pointId) {
        EnvironmentDataDTO data = sensorDataService.getCurrentData(pointId);
        if (data == null) {
            return ApiResponse.error("暂无数据");
        }
        return ApiResponse.success(data);
    }

    /**
     * 获取历史数据
     */
    @GetMapping("/history")
    public ApiResponse<List<EnvironmentDataDTO>> getHistoryData(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestParam(required = false, defaultValue = "100") int limit) {
        List<EnvironmentDataDTO> data = sensorDataService.getHistoryData(pointId, limit);
        return ApiResponse.success(data);
    }

    /**
     * 分页获取历史数据
     */
    @GetMapping("/history/paged")
    public ApiResponse<Page<EnvironmentDataDTO>> getHistoryDataPaged(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "20") int size) {
        Page<EnvironmentDataDTO> data = sensorDataService.getHistoryDataPaged(pointId, page, size);
        return ApiResponse.success(data);
    }

    /**
     * 按时间范围查询
     */
    @GetMapping("/history/range")
    public ApiResponse<List<EnvironmentDataDTO>> getHistoryDataByTimeRange(
            @RequestParam(required = false, defaultValue = "1") Long pointId,
            @RequestParam @DateTimeFormat(pattern = "yyyy-MM-dd HH:mm:ss") LocalDateTime startTime,
            @RequestParam @DateTimeFormat(pattern = "yyyy-MM-dd HH:mm:ss") LocalDateTime endTime) {
        List<EnvironmentDataDTO> data = sensorDataService.getHistoryDataByTimeRange(pointId, startTime, endTime);
        return ApiResponse.success(data);
    }

    /**
     * 上报环境数据（网关用）
     */
    @PostMapping
    public ApiResponse<EnvironmentDataDTO> uploadData(@RequestBody EnvironmentDataDTO dto) {
        EnvironmentDataDTO saved = sensorDataService.saveData(dto);
        return ApiResponse.success("数据上报成功", saved);
    }
}
