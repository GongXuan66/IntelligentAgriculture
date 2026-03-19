package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.MonitorPointService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 检测点管理接口
 */
@RestController
@RequestMapping("/point")
@RequiredArgsConstructor
@Slf4j
public class MonitorPointController {

    private final MonitorPointService monitorPointService;

    /**
     * 获取检测点列表
     */
    @GetMapping("/list")
    public ApiResponse<List<MonitorPointDTO>> getPointList(
            @RequestParam(required = false, defaultValue = "false") boolean activeOnly) {
        List<MonitorPointDTO> points;
        if (activeOnly) {
            points = monitorPointService.getActivePoints();
        } else {
            points = monitorPointService.getAllPoints();
        }
        return ApiResponse.success(points);
    }

    /**
     * 获取检测点详情
     */
    @GetMapping("/{id}")
    public ApiResponse<MonitorPointDTO> getPointById(@PathVariable Long id) {
        MonitorPointDTO point = monitorPointService.getPointById(id);
        if (point == null) {
            return ApiResponse.error("检测点不存在");
        }
        return ApiResponse.success(point);
    }

    /**
     * 添加检测点
     */
    @PostMapping
    public ApiResponse<MonitorPointDTO> createPoint(@Valid @RequestBody MonitorPointDTO.CreateRequest request) {
        try {
            MonitorPointDTO point = monitorPointService.createPoint(request);
            return ApiResponse.success("添加成功", point);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 更新检测点
     */
    @PutMapping("/{id}")
    public ApiResponse<MonitorPointDTO> updatePoint(
            @PathVariable Long id,
            @RequestBody MonitorPointDTO.UpdateRequest request) {
        try {
            MonitorPointDTO point = monitorPointService.updatePoint(id, request);
            return ApiResponse.success("更新成功", point);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 删除检测点
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deletePoint(@PathVariable Long id) {
        monitorPointService.deletePoint(id);
        return ApiResponse.success("删除成功", null);
    }
}
