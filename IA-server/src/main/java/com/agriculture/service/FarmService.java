package com.agriculture.service;

import com.agriculture.entity.Farm;
import com.agriculture.entity.MonitorPoint;
import com.agriculture.mapper.FarmMapper;
import com.agriculture.mapper.MonitorPointMapper;
import com.agriculture.model.dto.FarmDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class FarmService {

    private final FarmMapper farmMapper;
    private final MonitorPointMapper monitorPointMapper;

    /**
     * 获取所有农场列表
     */
    public List<FarmDTO> getAllFarms() {
        return farmMapper.selectList(null).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    /**
     * 根据用户ID获取农场列表
     */
    public List<FarmDTO> getFarmsByUserId(Long userId) {
        LambdaQueryWrapper<Farm> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Farm::getUserId, userId);
        return farmMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    /**
     * 获取启用的农场列表
     */
    public List<FarmDTO> getActiveFarms() {
        LambdaQueryWrapper<Farm> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Farm::getStatus, 1);
        return farmMapper.selectList(wrapper).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    /**
     * 获取农场详情（含检测点列表）
     */
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
                .map(this::toPointDTO)
                .collect(Collectors.toList()));

        return response;
    }

    /**
     * 根据ID获取农场
     */
    public FarmDTO getFarmById(Long id) {
        Farm farm = farmMapper.selectById(id);
        return farm != null ? toDTO(farm) : null;
    }

    /**
     * 获取农场下的检测点列表
     */
    public List<MonitorPointDTO> getPointsByFarmId(Long farmId) {
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, farmId);
        return monitorPointMapper.selectList(wrapper).stream()
                .map(this::toPointDTO)
                .collect(Collectors.toList());
    }

    /**
     * 创建农场
     */
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

    /**
     * 更新农场
     */
    @Transactional
    public FarmDTO updateFarm(Long id, FarmDTO.UpdateRequest request) {
        Farm farm = farmMapper.selectById(id);
        if (farm == null) {
            throw new RuntimeException("农场不存在: " + id);
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

    /**
     * 删除农场
     */
    @Transactional
    public void deleteFarm(Long id) {
        // 检查是否有关联的检测点
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, id);
        long count = monitorPointMapper.selectCount(wrapper);
        if (count > 0) {
            throw new RuntimeException("该农场下存在检测点，无法删除");
        }
        farmMapper.deleteById(id);
    }

    private FarmDTO toDTO(Farm farm) {
        FarmDTO dto = new FarmDTO();
        dto.setId(farm.getId());
        dto.setUserId(farm.getUserId());
        dto.setFarmName(farm.getFarmName());
        dto.setFarmCode(farm.getFarmCode());
        dto.setLocation(farm.getLocation());
        dto.setProvince(farm.getProvince());
        dto.setCity(farm.getCity());
        dto.setArea(farm.getArea());
        dto.setDescription(farm.getDescription());
        dto.setStatus(farm.getStatus());
        dto.setCreatedAt(farm.getCreatedAt());
        dto.setUpdatedAt(farm.getUpdatedAt());
        
        // 计算检测点数量
        LambdaQueryWrapper<MonitorPoint> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(MonitorPoint::getFarmId, farm.getId());
        Long count = monitorPointMapper.selectCount(wrapper);
        dto.setPointCount(count != null ? count.intValue() : 0);
        
        return dto;
    }

    private MonitorPointDTO toPointDTO(MonitorPoint point) {
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
        return dto;
    }
}
