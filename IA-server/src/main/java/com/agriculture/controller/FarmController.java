package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.dto.FarmDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.FarmService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 农场管理接口
 */
@RestController
@RequestMapping("/farm")
@RequiredArgsConstructor
@Slf4j
public class FarmController {

    private final FarmService farmService;

    /**
     * 获取农场列表
     */
    @GetMapping("/list")
    public ApiResponse<List<FarmDTO>> getFarmList(
            @RequestParam(required = false) Long userId,
            @RequestParam(required = false, defaultValue = "false") boolean activeOnly) {
        List<FarmDTO> farms;
        if (userId != null) {
            farms = farmService.getFarmsByUserId(userId);
        } else if (activeOnly) {
            farms = farmService.getActiveFarms();
        } else {
            farms = farmService.getAllFarms();
        }
        return ApiResponse.success(farms);
    }

    /**
     * 获取农场详情（含检测点列表）
     */
    @GetMapping("/{id}")
    public ApiResponse<FarmDTO.DetailResponse> getFarmDetail(@PathVariable Long id) {
        FarmDTO.DetailResponse detail = farmService.getFarmDetail(id);
        if (detail == null) {
            return ApiResponse.error("农场不存在");
        }
        return ApiResponse.success(detail);
    }

    /**
     * 获取农场下的检测点列表
     */
    @GetMapping("/{id}/points")
    public ApiResponse<List<MonitorPointDTO>> getFarmPoints(@PathVariable Long id) {
        List<MonitorPointDTO> points = farmService.getPointsByFarmId(id);
        return ApiResponse.success(points);
    }

    /**
     * 添加农场
     */
    @PostMapping
    public ApiResponse<FarmDTO> createFarm(@Valid @RequestBody FarmDTO.CreateRequest request) {
        FarmDTO farm = farmService.createFarm(request);
        return ApiResponse.success("添加成功", farm);
    }

    /**
     * 更新农场
     */
    @PutMapping("/{id}")
    public ApiResponse<FarmDTO> updateFarm(
            @PathVariable Long id,
            @RequestBody FarmDTO.UpdateRequest request) {
        FarmDTO farm = farmService.updateFarm(id, request);
        return ApiResponse.success("更新成功", farm);
    }

    /**
     * 删除农场
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteFarm(@PathVariable Long id) {
        farmService.deleteFarm(id);
        return ApiResponse.success("删除成功", null);
    }
}
