package com.agriculture.service.impl;

import com.agriculture.common.exception.DuplicateResourceException;
import com.agriculture.common.exception.ResourceNotFoundException;
import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.entity.Device;
import com.agriculture.common.converter.DeviceConverter;
import com.agriculture.mapper.DeviceMapper;
import com.agriculture.service.DeviceService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class DeviceServiceImpl implements DeviceService {

    private final DeviceMapper deviceMapper;
    private final DeviceConverter deviceConverter;

    @Override
    public List<DeviceDTO> getAllDevices() {
        return deviceMapper.selectList(null).stream()
                .map(deviceConverter::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public List<DeviceDTO> getDevicesByPointId(Long pointId) {
        return deviceMapper.findByPointId(pointId).stream()
                .map(deviceConverter::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public DeviceDTO getDeviceById(Long id) {
        Device device = deviceMapper.selectById(id);
        return device != null ? deviceConverter.toDTO(device) : null;
    }

    @Override
    public DeviceDTO getDeviceByDeviceCode(String deviceCode) {
        Device device = deviceMapper.findByDeviceCode(deviceCode);
        return device != null ? deviceConverter.toDTO(device) : null;
    }

    @Override
    @Transactional
    public DeviceDTO createDevice(DeviceDTO.CreateRequest request) {
        if (deviceMapper.existsByDeviceCode(request.getDeviceCode())) {
            throw new DuplicateResourceException("设备编码", request.getDeviceCode());
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
        return deviceConverter.toDTO(device);
    }

    @Override
    @Transactional
    public DeviceDTO updateDeviceStatus(String deviceCode, Integer status) {
        Device device = deviceMapper.findByDeviceCode(deviceCode);
        if (device == null) {
            throw new ResourceNotFoundException("设备", deviceCode);
        }

        device.setStatus(status);
        deviceMapper.updateById(device);
        return deviceConverter.toDTO(device);
    }

    @Override
    @Transactional
    public DeviceDTO controlDevice(String deviceCode, String command) {
        Device device = deviceMapper.findByDeviceCode(deviceCode);
        if (device == null) {
            throw new ResourceNotFoundException("设备", deviceCode);
        }

        switch (command.toLowerCase()) {
            case "on":
                device.setStatus(2);
                log.info("设备 {} 开启", deviceCode);
                break;
            case "off":
                device.setStatus(1);
                log.info("设备 {} 关闭", deviceCode);
                break;
            default:
                log.warn("未知命令: {}", command);
        }

        deviceMapper.updateById(device);
        return deviceConverter.toDTO(device);
    }

    @Override
    @Transactional
    public void deleteDevice(Long id) {
        deviceMapper.deleteById(id);
    }
}
