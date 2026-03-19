package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.service.DeviceService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 设备管理接口
 */
@RestController
@RequestMapping("/device")
@RequiredArgsConstructor
@Slf4j
public class DeviceController {

    private final DeviceService deviceService;

    /**
     * 获取设备列表
     */
    @GetMapping("/list")
    public ApiResponse<List<DeviceDTO>> getDeviceList(
            @RequestParam(required = false) Long pointId) {
        List<DeviceDTO> devices;
        if (pointId != null) {
            devices = deviceService.getDevicesByPointId(pointId);
        } else {
            devices = deviceService.getAllDevices();
        }
        return ApiResponse.success(devices);
    }

    /**
     * 获取设备详情
     */
    @GetMapping("/{id}")
    public ApiResponse<DeviceDTO> getDeviceById(@PathVariable Long id) {
        DeviceDTO device = deviceService.getDeviceById(id);
        if (device == null) {
            return ApiResponse.error("设备不存在");
        }
        return ApiResponse.success(device);
    }

    /**
     * 获取设备状态
     */
    @GetMapping("/{deviceId}/status")
    public ApiResponse<DeviceDTO> getDeviceStatus(@PathVariable String deviceId) {
        DeviceDTO device = deviceService.getDeviceByDeviceId(deviceId);
        if (device == null) {
            return ApiResponse.error("设备不存在");
        }
        return ApiResponse.success(device);
    }

    /**
     * 控制设备
     */
    @PostMapping("/control")
    public ApiResponse<DeviceDTO> controlDevice(@Valid @RequestBody DeviceDTO.ControlRequest request) {
        try {
            DeviceDTO device = deviceService.controlDevice(request.getDeviceId(), request.getCommand());
            return ApiResponse.success("控制成功", device);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 添加设备
     */
    @PostMapping
    public ApiResponse<DeviceDTO> createDevice(@Valid @RequestBody DeviceDTO.CreateRequest request) {
        try {
            DeviceDTO device = deviceService.createDevice(request);
            return ApiResponse.success("添加成功", device);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 删除设备
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteDevice(@PathVariable Long id) {
        deviceService.deleteDevice(id);
        return ApiResponse.success("删除成功", null);
    }
}
