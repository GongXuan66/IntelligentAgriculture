package com.agriculture.common.converter;

import com.agriculture.entity.SensorData;
import com.agriculture.model.dto.EnvironmentDataDTO;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface SensorDataConverter {

    EnvironmentDataDTO toDTO(SensorData sensorData);
}
