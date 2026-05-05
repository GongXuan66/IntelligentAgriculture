package com.agriculture.common.converter;

import com.agriculture.entity.IrrigationLog;
import com.agriculture.model.dto.IrrigationDTO;
import org.mapstruct.Mapper;

@Mapper(componentModel = "spring")
public interface IrrigationLogConverter {

    IrrigationDTO toDTO(IrrigationLog irrigationLog);
}
