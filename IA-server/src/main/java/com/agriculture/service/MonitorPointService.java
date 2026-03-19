package com.agriculture.service;

import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.entity.Field;
import com.agriculture.entity.MonitorPoint;
import com.agriculture.mapper.FieldMapper;
import com.agriculture.mapper.MonitorPointMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class MonitorPointService {

    private final MonitorPointMapper monitorPointMapper;
    private final FieldMapper fieldMapper;

    public List<MonitorPointDTO> getAllPoints() {
        return monitorPointMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<MonitorPointDTO> getActivePoints() {
        return monitorPointMapper.findByStatus(1).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public List<MonitorPointDTO> getPointsByFieldId(Long fieldId) {
        return monitorPointMapper.findByFieldId(fieldId).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public MonitorPointDTO getPointById(Long id) {
        MonitorPoint point = monitorPointMapper.selectById(id);
        return point != null ? toDTO(point) : null;
    }

    public MonitorPointDTO getPointByPointId(String pointId) {
        MonitorPoint point = monitorPointMapper.findByPointId(pointId);
        return point != null ? toDTO(point) : null;
    }

    @Transactional
    public MonitorPointDTO createPoint(MonitorPointDTO.CreateRequest request) {
        if (monitorPointMapper.existsByPointId(request.getPointId())) {
            throw new RuntimeException("检测点ID已存在: " + request.getPointId());
        }

        MonitorPoint point = new MonitorPoint();
        point.setFieldId(request.getFieldId());
        point.setPointId(request.getPointId());
        point.setPointName(request.getPointName());
        point.setLocation(request.getLocation());
        point.setCropType(request.getCropType());
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

        if (request.getFieldId() != null) {
            point.setFieldId(request.getFieldId());
        }
        if (request.getPointName() != null) {
            point.setPointName(request.getPointName());
        }
        if (request.getLocation() != null) {
            point.setLocation(request.getLocation());
        }
        if (request.getCropType() != null) {
            point.setCropType(request.getCropType());
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
        dto.setFieldId(point.getFieldId());
        dto.setPointId(point.getPointId());
        dto.setPointName(point.getPointName());
        dto.setLocation(point.getLocation());
        dto.setCropType(point.getCropType());
        dto.setStatus(point.getStatus());
        dto.setCreatedAt(point.getCreatedAt());
        dto.setUpdatedAt(point.getUpdatedAt());
        
        // 获取关联的地块名称
        if (point.getFieldId() != null) {
            Field field = fieldMapper.selectById(point.getFieldId());
            if (field != null) {
                dto.setFieldName(field.getFieldName());
            }
        }
        
        return dto;
    }
}
