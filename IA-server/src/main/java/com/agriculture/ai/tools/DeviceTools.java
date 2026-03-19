package com.agriculture.ai.tools;

import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.service.DeviceService;
import dev.langchain4j.agent.tool.Tool;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 设备管理工具类
 * 为 AI 助手提供设备查询和控制能力
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class DeviceTools {

    private final DeviceService deviceService;

    @Tool("获取系统中所有设备列表，包括设备的ID、名称、类型和当前状态")
    public List<DeviceDTO> getAllDevices() {
        log.info("[AI Tool] 获取所有设备列表");
        return deviceService.getAllDevices();
    }

    @Tool("根据检测点ID获取该检测点下的所有设备")
    public List<DeviceDTO> getDevicesByPointId(Long pointId) {
        log.info("[AI Tool] 获取检测点 {} 的设备列表", pointId);
        return deviceService.getDevicesByPointId(pointId);
    }

    @Tool("根据设备ID获取设备的详细信息")
    public DeviceDTO getDeviceByDeviceId(String deviceId) {
        log.info("[AI Tool] 获取设备 {} 的详细信息", deviceId);
        return deviceService.getDeviceByDeviceId(deviceId);
    }

    @Tool("控制设备开关。command参数为'on'开启设备，'off'关闭设备")
    public DeviceDTO controlDevice(String deviceId, String command) {
        log.info("[AI Tool] 控制设备 {} 执行命令: {}", deviceId, command);
        return deviceService.controlDevice(deviceId, command);
    }

    @Tool("更新设备状态。status: 0-离线, 1-在线, 2-工作中")
    public DeviceDTO updateDeviceStatus(String deviceId, Integer status) {
        log.info("[AI Tool] 更新设备 {} 状态为: {}", deviceId, status);
        return deviceService.updateDeviceStatus(deviceId, status);
    }
}
