package com.agriculture.controller;

import com.agriculture.model.response.ApiResponse;
import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Random;

/**
 * 测试接口控制器 - 用于开发和测试
 */
@RestController
@RequestMapping("/test")
@RequiredArgsConstructor
@Slf4j
public class TestController {

    private final MockGatewayService mockGatewayService;
    private final MonitorPointService monitorPointService;
    private final DeviceService deviceService;
    private final SensorDataService sensorDataService;
    private final IrrigationService irrigationService;
    private final AlarmService alarmService;

    /**
     * 获取系统状态
     */
    @GetMapping("/status")
    public ApiResponse<Map<String, Object>> getStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("mockEnabled", mockGatewayService.isEnabled());
        status.put("pointsCount", monitorPointService.getAllPoints().size());
        status.put("devicesCount", deviceService.getAllDevices().size());
        status.put("unprocessedAlarms", alarmService.getUnprocessedCount());
        return ApiResponse.success(status);
    }

    /**
     * 开启/关闭模拟网关
     */
    @PostMapping("/mock/toggle")
    public ApiResponse<String> toggleMock(@RequestParam(defaultValue = "true") boolean enabled) {
        mockGatewayService.setEnabled(enabled);
        return ApiResponse.success(enabled ? "模拟网关已启动" : "模拟网关已停止");
    }

    /**
     * 设置模拟检测点
     */
    @PostMapping("/mock/point")
    public ApiResponse<String> setMockPoint(@RequestParam Long pointId) {
        mockGatewayService.setMockPointId(pointId);
        return ApiResponse.success("模拟检测点已设置为: " + pointId);
    }

    /**
     * 模拟灌溉
     */
    @PostMapping("/mock/irrigation")
    public ApiResponse<String> mockIrrigation(@RequestParam(defaultValue = "5") BigDecimal waterAmount) {
        mockGatewayService.simulateIrrigation(waterAmount);
        return ApiResponse.success("模拟灌溉完成，土壤湿度上升");
    }

    /**
     * 重置模拟基准值
     */
    @PostMapping("/mock/reset")
    public ApiResponse<String> resetMock() {
        mockGatewayService.resetBaseValues();
        return ApiResponse.success("基准值已重置");
    }

    /**
     * 手动生成一条环境数据
     */
    @PostMapping("/data/generate")
    public ApiResponse<EnvironmentDataDTO> generateData(@RequestParam(defaultValue = "1") Long pointId) {
        EnvironmentDataDTO data = mockGatewayService.generateOneData(pointId);
        return ApiResponse.success("生成成功", data);
    }

    /**
     * 批量生成历史数据
     */
    @PostMapping("/data/batch")
    public ApiResponse<String> batchGenerateData(
            @RequestParam(defaultValue = "1") Long pointId,
            @RequestParam(defaultValue = "100") int count) {

        Random random = new Random();
        LocalDateTime now = LocalDateTime.now();

        for (int i = 0; i < count; i++) {
            EnvironmentDataDTO dto = new EnvironmentDataDTO();
            dto.setPointId(pointId);
            dto.setRecordedAt(now.minusMinutes(count - i)); // 每分钟一条

            // 生成随机数据
            dto.setTemperature(BigDecimal.valueOf(20 + random.nextDouble() * 15).setScale(2, RoundingMode.HALF_UP));
            dto.setHumidity(BigDecimal.valueOf(40 + random.nextDouble() * 40).setScale(2, RoundingMode.HALF_UP));
            dto.setLight(BigDecimal.valueOf(300 + random.nextDouble() * 700).setScale(2, RoundingMode.HALF_UP));
            dto.setCo2(BigDecimal.valueOf(300 + random.nextDouble() * 600).setScale(2, RoundingMode.HALF_UP));
            dto.setSoilMoisture(BigDecimal.valueOf(30 + random.nextDouble() * 40).setScale(2, RoundingMode.HALF_UP));

            sensorDataService.saveData(dto);
        }

        return ApiResponse.success("已生成 " + count + " 条历史数据");
    }

    /**
     * 快速创建检测点和设备
     */
    @PostMapping("/init/quick")
    public ApiResponse<Map<String, Object>> quickInit() {
        Map<String, Object> result = new HashMap<>();

        // 创建检测点
        if (monitorPointService.getAllPoints().isEmpty()) {
            MonitorPointDTO.CreateRequest pointRequest = new MonitorPointDTO.CreateRequest();
            pointRequest.setPointCode("POINT_001");
            pointRequest.setPointName("1号大棚");
            pointRequest.setLocation("东区");
            result.put("point", monitorPointService.createPoint(pointRequest));
        }

        // 创建设备
        if (deviceService.getAllDevices().isEmpty()) {
            String[][] devices = {
                {"pump_001", "水泵1号", "pump"},
                {"valve_001", "水阀1号", "valve"},
                {"led_001", "LED补光灯1号", "led"},
                {"fan_001", "通风风扇1号", "fan"}
            };

            for (String[] d : devices) {
                DeviceDTO.CreateRequest deviceRequest = new DeviceDTO.CreateRequest();
                deviceRequest.setPointId(1L);
                deviceRequest.setDeviceCode(d[0]);
                deviceRequest.setDeviceName(d[1]);
                deviceRequest.setDeviceType(d[2]);
                deviceService.createDevice(deviceRequest);
            }
            result.put("devices", 4);
        }

        return ApiResponse.success("初始化完成", result);
    }

    /**
     * 测试灌溉流程
     */
    @PostMapping("/irrigation/test")
    public ApiResponse<Map<String, Object>> testIrrigation(
            @RequestParam(defaultValue = "1") Long pointId) {
        Map<String, Object> result = new HashMap<>();

        // 开始灌溉
        IrrigationDTO.StartRequest startRequest = new IrrigationDTO.StartRequest();
        startRequest.setPointId(pointId);
        startRequest.setMode(0);
        IrrigationDTO start = irrigationService.startIrrigation(startRequest);
        result.put("start", start);

        // 模拟灌溉效果
        mockGatewayService.simulateIrrigation(new BigDecimal("10"));

        // 停止灌溉
        IrrigationDTO stop = irrigationService.stopIrrigation(start.getId());
        result.put("stop", stop);

        return ApiResponse.success("灌溉测试完成", result);
    }

    /**
     * 清理所有报警
     */
    @PostMapping("/alarm/clear-all")
    public ApiResponse<String> clearAllAlarms() {
        alarmService.getAllAlarms().forEach(alarm -> {
            if (alarm.getStatus() == 0) {
                alarmService.handleAlarm(alarm.getId(), "批量处理");
            }
        });
        return ApiResponse.success("所有报警已处理");
    }
}
