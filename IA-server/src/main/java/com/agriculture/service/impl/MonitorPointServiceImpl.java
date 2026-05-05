package com.agriculture.service.impl;

import com.agriculture.common.exception.ResourceNotFoundException;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.common.converter.MonitorPointConverter;
import com.agriculture.entity.Farm;
import com.agriculture.entity.MonitorPoint;
import com.agriculture.mapper.FarmMapper;
import com.agriculture.mapper.MonitorPointMapper;
import com.agriculture.service.MonitorPointService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MonitorPointServiceImpl implements MonitorPointService {

    private final MonitorPointMapper monitorPointMapper;
    private final FarmMapper farmMapper;
    private final MonitorPointConverter monitorPointConverter;

    @Override
    public List<MonitorPointDTO> getAllPoints() {
        return monitorPointMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public List<MonitorPointDTO> getActivePoints() {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getStatus, 1);
        return monitorPointMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public List<MonitorPointDTO> getPointsByFarmId(Long farmId) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, farmId);
        return monitorPointMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public MonitorPointDTO getPointById(Long id) {
        MonitorPoint point = monitorPointMapper.selectById(id);
        return point != null ? toDTO(point) : null;
    }

    @Override
    public MonitorPointDTO getPointByPointCode(String pointCode) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getPointCode, pointCode);
        MonitorPoint point = monitorPointMapper.selectOne(wrapper);
        return point != null ? toDTO(point) : null;
    }

    @Override
    public MonitorPointDTO getPointByPointId(String pointId) {
        return getPointByPointCode(pointId);
    }

    @Override
    public List<MonitorPointDTO> getPointsByFieldId(Long fieldId) {
        return getPointsByFarmId(fieldId);
    }

    @Override
    @Transactional
    public MonitorPointDTO createPoint(MonitorPointDTO.CreateRequest request) {
        MonitorPoint point = new MonitorPoint();
        point.setFarmId(request.getFarmId());
        point.setPointCode(request.getPointCode());
        point.setPointName(request.getPointName());
        point.setLocation(request.getLocation());
        point.setArea(request.getArea());
        point.setSoilType(request.getSoilType());
        point.setStatus(1);

        monitorPointMapper.insert(point);
        return toDTO(point);
    }

    @Override
    @Transactional
    public MonitorPointDTO updatePoint(Long id, MonitorPointDTO.UpdateRequest request) {
        MonitorPoint point = monitorPointMapper.selectById(id);
        if (point == null) {
            throw new ResourceNotFoundException("检测点", id);
        }

        if (request.getFarmId() != null) {
            point.setFarmId(request.getFarmId());
        }
        if (request.getPointCode() != null) {
            point.setPointCode(request.getPointCode());
        }
        if (request.getPointName() != null) {
            point.setPointName(request.getPointName());
        }
        if (request.getLocation() != null) {
            point.setLocation(request.getLocation());
        }
        if (request.getArea() != null) {
            point.setArea(request.getArea());
        }
        if (request.getSoilType() != null) {
            point.setSoilType(request.getSoilType());
        }
        if (request.getStatus() != null) {
            point.setStatus(request.getStatus());
        }

        monitorPointMapper.updateById(point);
        return toDTO(point);
    }

    @Override
    @Transactional
    public void deletePoint(Long id) {
        monitorPointMapper.deleteById(id);
    }

    private MonitorPointDTO toDTO(MonitorPoint point) {
        MonitorPointDTO dto = monitorPointConverter.toDTO(point);

        if (point.getFarmId() != null) {
            Farm farm = farmMapper.selectById(point.getFarmId());
            if (farm != null) {
                dto.setFarmName(farm.getFarmName());
            }
        }

        return dto;
    }
}
