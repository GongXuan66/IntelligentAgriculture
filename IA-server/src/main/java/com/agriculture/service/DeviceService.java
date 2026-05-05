package com.agriculture.service;

import com.agriculture.model.dto.DeviceDTO;

import java.util.List;

public interface DeviceService {

    List<DeviceDTO> getAllDevices();

    List<DeviceDTO> getDevicesByPointId(Long pointId);

    DeviceDTO getDeviceById(Long id);

    DeviceDTO getDeviceByDeviceCode(String deviceCode);

    DeviceDTO createDevice(DeviceDTO.CreateRequest request);

    DeviceDTO updateDeviceStatus(String deviceCode, Integer status);

    DeviceDTO controlDevice(String deviceCode, String command);

    void deleteDevice(Long id);
}
