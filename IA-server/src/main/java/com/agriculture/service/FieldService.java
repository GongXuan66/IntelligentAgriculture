package com.agriculture.service;

import com.agriculture.entity.Field;
import com.agriculture.entity.MonitorPoint;
import com.agriculture.mapper.FieldMapper;
import com.agriculture.mapper.MonitorPointMapper;
import com.agriculture.model.dto.FieldDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FieldService {

    private final FieldMapper fieldMapper;
    private final MonitorPointMapper monitorPointMapper;

    /**
     * 获取所有地块列表
     */
    public List<FieldDTO> getAllFields() {
        return fieldMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    /**
     * 获取启用的地块列表
     */
    public List<FieldDTO> getActiveFields() {
        return fieldMapper.findByStatus(1).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    /**
     * 获取地块详情（含检测点列表）
     */
    public FieldDTO.DetailResponse getFieldDetail(Long id) {
        Field field = fieldMapper.selectById(id);
        if (field == null) {
            return null;
        }

        FieldDTO.DetailResponse response = new FieldDTO.DetailResponse();
        response.setField(toDTO(field));

        List<MonitorPoint> points = monitorPointMapper.findByFieldId(id);
        response.setPoints(points.stream()
                .map(this::toPointDTO)
                .collect(Collectors.toList()));

        return response;
    }

    /**
     * 根据ID获取地块
     */
    public FieldDTO getFieldById(Long id) {
        Field field = fieldMapper.selectById(id);
        return field != null ? toDTO(field) : null;
    }

    /**
     * 根据编号获取地块
     */
    public FieldDTO getFieldByFieldId(String fieldId) {
        Field field = fieldMapper.findByFieldId(fieldId);
        return field != null ? toDTO(field) : null;
    }

    /**
     * 获取地块下的检测点列表
     */
    public List<MonitorPointDTO> getPointsByFieldId(Long fieldId) {
        return monitorPointMapper.findByFieldId(fieldId).stream()
                .map(this::toPointDTO)
                .collect(Collectors.toList());
    }

    /**
     * 创建地块
     */
    @Transactional
    public FieldDTO createField(FieldDTO.CreateRequest request) {
        if (fieldMapper.existsByFieldId(request.getFieldId())) {
            throw new RuntimeException("地块编号已存在: " + request.getFieldId());
        }

        Field field = new Field();
        field.setFieldId(request.getFieldId());
        field.setFieldName(request.getFieldName());
        field.setFieldType(request.getFieldType() != null ? request.getFieldType() : "outdoor");
        field.setLocation(request.getLocation());
        field.setArea(request.getArea());
        field.setCropType(request.getCropType());
        field.setDescription(request.getDescription());
        field.setStatus(1);

        fieldMapper.insert(field);
        return toDTO(field);
    }

    /**
     * 更新地块
     */
    @Transactional
    public FieldDTO updateField(Long id, FieldDTO.UpdateRequest request) {
        Field field = fieldMapper.selectById(id);
        if (field == null) {
            throw new RuntimeException("地块不存在: " + id);
        }

        if (request.getFieldName() != null) {
            field.setFieldName(request.getFieldName());
        }
        if (request.getFieldType() != null) {
            field.setFieldType(request.getFieldType());
        }
        if (request.getLocation() != null) {
            field.setLocation(request.getLocation());
        }
        if (request.getArea() != null) {
            field.setArea(request.getArea());
        }
        if (request.getCropType() != null) {
            field.setCropType(request.getCropType());
        }
        if (request.getDescription() != null) {
            field.setDescription(request.getDescription());
        }
        if (request.getStatus() != null) {
            field.setStatus(request.getStatus());
        }

        fieldMapper.updateById(field);
        return toDTO(field);
    }

    /**
     * 删除地块
     */
    @Transactional
    public void deleteField(Long id) {
        // 检查是否有关联的检测点
        List<MonitorPoint> points = monitorPointMapper.findByFieldId(id);
        if (!points.isEmpty()) {
            throw new RuntimeException("该地块下存在检测点，无法删除");
        }
        fieldMapper.deleteById(id);
    }

    private FieldDTO toDTO(Field field) {
        FieldDTO dto = new FieldDTO();
        dto.setId(field.getId());
        dto.setFieldId(field.getFieldId());
        dto.setFieldName(field.getFieldName());
        dto.setFieldType(field.getFieldType());
        dto.setLocation(field.getLocation());
        dto.setArea(field.getArea());
        dto.setCropType(field.getCropType());
        dto.setDescription(field.getDescription());
        dto.setStatus(field.getStatus());
        dto.setCreatedAt(field.getCreatedAt());
        dto.setUpdatedAt(field.getUpdatedAt());
        
        // 计算检测点数量
        List<MonitorPoint> points = monitorPointMapper.findByFieldId(field.getId());
        dto.setPointCount(points.size());
        
        return dto;
    }

    private MonitorPointDTO toPointDTO(MonitorPoint point) {
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
        return dto;
    }
}
