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

    public DeviceDTO getDeviceByDeviceCode(String deviceCode) {
        Device device = deviceMapper.findByDeviceCode(deviceCode);
        return device != null ? toDTO(device) : null;
    }

    @Transactional
    public DeviceDTO createDevice(DeviceDTO.CreateRequest request) {
        if (deviceMapper.existsByDeviceCode(request.getDeviceCode())) {
            throw new RuntimeException("设备编码已存在: " + request.getDeviceCode());
        }

        Device device = new Device();
        device.setPointId(request.getPointId());
        device.setDeviceCode(request.getDeviceCode());
        device.setDeviceName(request.getDeviceName());
        device.setDeviceType(request.getDeviceType());
        device.setDeviceModel(request.getDeviceModel());
        device.setManufacturer(request.getManufacturer());
        device.setStatus(0);

        deviceMapper.insert(device);
        return toDTO(device);
    }

    @Transactional
    public DeviceDTO updateDeviceStatus(String deviceCode, Integer status) {
        Device device = deviceMapper.findByDeviceCode(deviceCode);
        if (device == null) {
            throw new RuntimeException("设备不存在: " + deviceCode);
        }

        device.setStatus(status);
        deviceMapper.updateById(device);
        return toDTO(device);
    }

    @Transactional
    public DeviceDTO controlDevice(String deviceCode, String command) {
        Device device = deviceMapper.findByDeviceCode(deviceCode);
        if (device == null) {
            throw new RuntimeException("设备不存在: " + deviceCode);
        }

        // 根据命令更新设备状态
        // on: 开启设备 (状态变为工作中)
        // off: 关闭设备 (状态变为在线)
        switch (command.toLowerCase()) {
            case "on":
                device.setStatus(2); // 工作中
                log.info("设备 {} 开启", deviceCode);
                break;
            case "off":
                device.setStatus(1); // 在线
                log.info("设备 {} 关闭", deviceCode);
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
        dto.setDeviceCode(device.getDeviceCode());
        dto.setDeviceName(device.getDeviceName());
        dto.setDeviceType(device.getDeviceType());
        dto.setDeviceModel(device.getDeviceModel());
        dto.setManufacturer(device.getManufacturer());
        dto.setStatus(device.getStatus());
        dto.setLastHeartbeat(device.getLastHeartbeat());
        dto.setInstalledAt(device.getInstalledAt());
        dto.setCreatedAt(device.getCreatedAt());
        dto.setUpdatedAt(device.getUpdatedAt());
        return dto;
    }
}
