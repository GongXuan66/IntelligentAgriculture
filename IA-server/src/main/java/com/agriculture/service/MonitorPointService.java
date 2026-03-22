package com.agriculture.service;

import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.entity.Farm;
import com.agriculture.entity.MonitorPoint;
import com.agriculture.mapper.FarmMapper;
import com.agriculture.mapper.MonitorPointMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MonitorPointService {

    private final MonitorPointMapper monitorPointMapper;
    private final FarmMapper farmMapper;

    public List<MonitorPointDTO> getAllPoints() {
        return monitorPointMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<MonitorPointDTO> getActivePoints() {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getStatus, 1);
        return monitorPointMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<MonitorPointDTO> getPointsByFarmId(Long farmId) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, farmId);
        return monitorPointMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public MonitorPointDTO getPointById(Long id) {
        MonitorPoint point = monitorPointMapper.selectById(id);
        return point != null ? toDTO(point) : null;
    }

    public MonitorPointDTO getPointByPointCode(String pointCode) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getPointCode, pointCode);
        MonitorPoint point = monitorPointMapper.selectOne(wrapper);
        return point != null ? toDTO(point) : null;
    }

    /**
     * 根据检测点编号获取检测点（别名方法）
     */
    public MonitorPointDTO getPointByPointId(String pointId) {
        return getPointByPointCode(pointId);
    }

    /**
     * 根据农场ID获取检测点列表（兼容旧方法名）
     */
    public List<MonitorPointDTO> getPointsByFieldId(Long fieldId) {
        return getPointsByFarmId(fieldId);
    }

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

    @Transactional
    public MonitorPointDTO updatePoint(Long id, MonitorPointDTO.UpdateRequest request) {
        MonitorPoint point = monitorPointMapper.selectById(id);
        if (point == null) {
            throw new RuntimeException("检测点不存在: " + id);
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

    @Transactional
    public void deletePoint(Long id) {
        monitorPointMapper.deleteById(id);
    }

    private MonitorPointDTO toDTO(MonitorPoint point) {
        MonitorPointDTO dto = new MonitorPointDTO();
        dto.setId(point.getId());
        dto.setFarmId(point.getFarmId());
        dto.setPointCode(point.getPointCode());
        dto.setPointName(point.getPointName());
        dto.setLocation(point.getLocation());
        dto.setArea(point.getArea());
        dto.setSoilType(point.getSoilType());
        dto.setStatus(point.getStatus());
        dto.setCreatedAt(point.getCreatedAt());
        dto.setUpdatedAt(point.getUpdatedAt());
        
        // 获取关联的农场名称
        if (point.getFarmId() != null) {
            Farm farm = farmMapper.selectById(point.getFarmId());
            if (farm != null) {
                dto.setFarmName(farm.getFarmName());
            }
        }
        
        return dto;
    }
}