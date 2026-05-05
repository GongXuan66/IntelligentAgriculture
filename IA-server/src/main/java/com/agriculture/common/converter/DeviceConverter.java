package com.agriculture.common.converter;

import com.agriculture.entity.Device;
import com.agriculture.model.dto.DeviceDTO;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface DeviceConverter {

    DeviceDTO toDTO(Device device);
}
