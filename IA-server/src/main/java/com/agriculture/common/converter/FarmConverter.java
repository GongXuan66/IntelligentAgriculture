package com.agriculture.common.converter;

import com.agriculture.entity.Farm;
import com.agriculture.model.dto.FarmDTO;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface FarmConverter {

    @Mapping(target = "pointCount", ignore = true)
    FarmDTO toDTO(Farm farm);
}
