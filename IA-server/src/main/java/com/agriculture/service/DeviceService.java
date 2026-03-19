package com.agriculture.service;

import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.entity.Device;
import com.agriculture.mapper.DeviceMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceService {

    private final DeviceMapper deviceMapper;

    public List<DeviceDTO> getAllDevices() {
        return deviceMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<DeviceDTO> getDevicesByPointId(Long pointId) {
        return deviceMapper.findByPointId(pointId).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public DeviceDTO getDeviceById(Long id) {
        Device device = deviceMapper.selectById(id);
        return device != null ? toDTO(device) : null;
    }

    public DeviceDTO getDeviceByDeviceId(String deviceId) {
        Device device = deviceMapper.findByDeviceId(deviceId);
        return device != null ? toDTO(device) : null;
    }

    @Transactional
    public DeviceDTO createDevice(DeviceDTO.CreateRequest request) {
        if (deviceMapper.existsByDeviceId(request.getDeviceId())) {
            throw new RuntimeException("设备ID已存在: " + request.getDeviceId());
        }

        Device device = new Device();
        device.setPointId(request.getPointId());
        device.setDeviceId(request.getDeviceId());
        device.setDeviceName(request.getDeviceName());
        device.setDeviceType(request.getDeviceType());
        device.setStatus(0);

        deviceMapper.insert(device);
        return toDTO(device);
    }

    @Transactional
    public DeviceDTO updateDeviceStatus(String deviceId, Integer status) {
        Device device = deviceMapper.findByDeviceId(deviceId);
        if (device == null) {
            throw new RuntimeException("设备不存在: " + deviceId);
        }

        device.setStatus(status);
        deviceMapper.updateById(device);
        return toDTO(device);
    }

    @Transactional
    public DeviceDTO controlDevice(String deviceId, String command) {
        Device device = deviceMapper.findByDeviceId(deviceId);
        if (device == null) {
            throw new RuntimeException("设备不存在: " + deviceId);
        }

        // 根据命令更新设备状态
        // on: 开启设备 (状态变为工作中)
        // off: 关闭设备 (状态变为在线)
        switch (command.toLowerCase()) {
            case "on":
                device.setStatus(2); // 工作中
                log.info("设备 {} 开启", deviceId);
                break;
            case "off":
                device.setStatus(1); // 在线
                log.info("设备 {} 关闭", deviceId);
                break;
            default:
                log.warn("未知命令: {}", command);
        }

        deviceMapper.updateById(device);
        return toDTO(device);
    }

    @Transactional
    public void deleteDevice(Long id) {
        deviceMapper.deleteById(id);
    }

    private DeviceDTO toDTO(Device device) {
        DeviceDTO dto = new DeviceDTO();
        dto.setId(device.getId());
        dto.setPointId(device.getPointId());
        dto.setDeviceId(device.getDeviceId());
        dto.setDeviceName(device.getDeviceName());
        dto.setDeviceType(device.getDeviceType());
        dto.setStatus(device.getStatus());
        dto.setCreatedAt(device.getCreatedAt());
        dto.setUpdatedAt(device.getUpdatedAt());
        return dto;
    }
}
