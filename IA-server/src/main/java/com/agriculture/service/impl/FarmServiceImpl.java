package com.agriculture.service.impl;

import com.agriculture.common.exception.InvalidOperationException;
import com.agriculture.common.exception.ResourceNotFoundException;
import com.agriculture.common.converter.FarmConverter;
import com.agriculture.common.converter.MonitorPointConverter;
import com.agriculture.entity.Farm;
import com.agriculture.entity.MonitorPoint;
import com.agriculture.mapper.FarmMapper;
import com.agriculture.mapper.MonitorPointMapper;
import com.agriculture.model.dto.FarmDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.FarmService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FarmServiceImpl implements FarmService {

    private final FarmMapper farmMapper;
    private final MonitorPointMapper monitorPointMapper;
    private final FarmConverter farmConverter;
    private final MonitorPointConverter monitorPointConverter;

    @Override
    public List<FarmDTO> getAllFarms() {
        return farmMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public List<FarmDTO> getFarmsByUserId(Long userId) {
        LambdaQueryWrapper<Farm> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Farm::getUserId, userId);
        return farmMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public List<FarmDTO> getActiveFarms() {
        LambdaQueryWrapper<Farm> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Farm::getStatus, 1);
        return farmMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public FarmDTO.DetailResponse getFarmDetail(Long id) {
        Farm farm = farmMapper.selectById(id);
        if (farm == null) {
            return null;
        }

        FarmDTO.DetailResponse response = new FarmDTO.DetailResponse();
        response.setFarm(toDTO(farm));

        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, id);
        List<MonitorPoint> points = monitorPointMapper.selectList(wrapper);
        response.setPoints(points.stream()
                .map(monitorPointConverter::toDTO)
                .collect(Collectors.toList()));

        return response;
    }

    @Override
    public FarmDTO getFarmById(Long id) {
        Farm farm = farmMapper.selectById(id);
        return farm != null ? toDTO(farm) : null;
    }

    @Override
    public List<MonitorPointDTO> getPointsByFarmId(Long farmId) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, farmId);
        return monitorPointMapper.selectList(wrapper).stream()
                .map(monitorPointConverter::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    @Transactional
    public FarmDTO createFarm(FarmDTO.CreateRequest request) {
        Farm farm = new Farm();
        farm.setUserId(request.getUserId());
        farm.setFarmName(request.getFarmName());
        farm.setFarmCode(request.getFarmCode());
        farm.setLocation(request.getLocation());
        farm.setProvince(request.getProvince());
        farm.setCity(request.getCity());
        farm.setArea(request.getArea());
        farm.setDescription(request.getDescription());
        farm.setStatus(1);

        farmMapper.insert(farm);
        return toDTO(farm);
    }

    @Override
    @Transactional
    public FarmDTO updateFarm(Long id, FarmDTO.UpdateRequest request) {
        Farm farm = farmMapper.selectById(id);
        if (farm == null) {
            throw new ResourceNotFoundException("农场", id);
        }

        if (request.getFarmName() != null) {
            farm.setFarmName(request.getFarmName());
        }
        if (request.getLocation() != null) {
            farm.setLocation(request.getLocation());
        }
        if (request.getProvince() != null) {
            farm.setProvince(request.getProvince());
        }
        if (request.getCity() != null) {
            farm.setCity(request.getCity());
        }
        if (request.getArea() != null) {
            farm.setArea(request.getArea());
        }
        if (request.getDescription() != null) {
            farm.setDescription(request.getDescription());
        }
        if (request.getStatus() != null) {
            farm.setStatus(request.getStatus());
        }

        farmMapper.updateById(farm);
        return toDTO(farm);
    }

    @Override
    @Transactional
    public void deleteFarm(Long id) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, id);
        long count = monitorPointMapper.selectCount(wrapper);
        if (count > 0) {
            throw new InvalidOperationException("该农场下存在检测点，无法删除");
        }
        farmMapper.deleteById(id);
    }

    private FarmDTO toDTO(Farm farm) {
        FarmDTO dto = farmConverter.toDTO(farm);

        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, farm.getId());
        Long pointCount = monitorPointMapper.selectCount(wrapper);
        dto.setPointCount(pointCount != null ? pointCount.intValue() : 0);

        return dto;
    }
}
