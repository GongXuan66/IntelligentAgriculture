package com.agriculture.common.converter;

import com.agriculture.entity.Alarm;
import com.agriculture.model.dto.AlarmDTO;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface AlarmConverter {

    AlarmDTO toDTO(Alarm alarm);
}
