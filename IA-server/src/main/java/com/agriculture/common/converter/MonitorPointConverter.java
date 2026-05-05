package com.agriculture.common.converter;

import com.agriculture.entity.MonitorPoint;
import com.agriculture.model.dto.MonitorPointDTO;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface MonitorPointConverter {

    @Mapping(target = "farmName", ignore = true)
    MonitorPointDTO toDTO(MonitorPoint point);
}
