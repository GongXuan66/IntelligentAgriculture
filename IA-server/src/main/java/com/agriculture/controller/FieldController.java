package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.dto.FieldDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.FieldService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 地块管理接口
 */
@RestController
@RequestMapping("/field")
@RequiredArgsConstructor
@Slf4j
public class FieldController {

    private final FieldService fieldService;

    /**
     * 获取地块列表
     */
    @GetMapping("/list")
    public ApiResponse<List<FieldDTO>> getFieldList(
            @RequestParam(required = false, defaultValue = "false") boolean activeOnly) {
        List<FieldDTO> fields;
        if (activeOnly) {
            fields = fieldService.getActiveFields();
        } else {
            fields = fieldService.getAllFields();
        }
        return ApiResponse.success(fields);
    }

    /**
     * 获取地块详情（含检测点列表）
     */
    @GetMapping("/{id}")
    public ApiResponse<FieldDTO.DetailResponse> getFieldDetail(@PathVariable Long id) {
        FieldDTO.DetailResponse detail = fieldService.getFieldDetail(id);
        if (detail == null) {
            return ApiResponse.error("地块不存在");
        }
        return ApiResponse.success(detail);
    }

    /**
     * 获取地块下的检测点列表
     */
    @GetMapping("/{id}/points")
    public ApiResponse<List<MonitorPointDTO>> getFieldPoints(@PathVariable Long id) {
        List<MonitorPointDTO> points = fieldService.getPointsByFieldId(id);
        return ApiResponse.success(points);
    }

    /**
     * 添加地块
     */
    @PostMapping
    public ApiResponse<FieldDTO> createField(@Valid @RequestBody FieldDTO.CreateRequest request) {
        try {
            FieldDTO field = fieldService.createField(request);
            return ApiResponse.success("添加成功", field);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 更新地块
     */
    @PutMapping("/{id}")
    public ApiResponse<FieldDTO> updateField(
            @PathVariable Long id,
            @RequestBody FieldDTO.UpdateRequest request) {
        try {
            FieldDTO field = fieldService.updateField(id, request);
            return ApiResponse.success("更新成功", field);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 删除地块
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteField(@PathVariable Long id) {
        try {
            fieldService.deleteField(id);
            return ApiResponse.success("删除成功", null);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }
}
