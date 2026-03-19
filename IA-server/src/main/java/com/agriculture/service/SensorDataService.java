package com.agriculture.service;

import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.entity.Alarm;
import com.agriculture.entity.SensorData;
import com.agriculture.mapper.AlarmMapper;
import com.agriculture.mapper.SensorDataMapper;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class SensorDataService {

    private final SensorDataMapper sensorDataMapper;
    private final AlarmMapper alarmMapper;
    private final EnvironmentCacheService environmentCacheService;

    private static final BigDecimal TEMP_MIN = new BigDecimal("10");
    private static final BigDecimal TEMP_MAX = new BigDecimal("35");
    private static final BigDecimal HUMIDITY_MIN = new BigDecimal("30");
    private static final BigDecimal HUMIDITY_MAX = new BigDecimal("80");
    private static final BigDecimal LIGHT_MIN = new BigDecimal("300");
    private static final BigDecimal CO2_MAX = new BigDecimal("1000");
    private static final BigDecimal SOIL_MOISTURE_MIN = new BigDecimal("40");

    public EnvironmentDataDTO getCurrentData(Long pointId) {
        EnvironmentDataDTO cached = environmentCacheService.get(pointId);
        if (cached != null) {
            return cached;
        }

        SensorData data = sensorDataMapper.findFirstByPointIdOrderByRecordedAtDesc(pointId);
        if (data == null) {
            return null;
        }

        EnvironmentDataDTO dto = toDTO(data);
        environmentCacheService.put(pointId, dto);
        return dto;
    }

    public List<EnvironmentDataDTO> getHistoryData(Long pointId, int limit) {
        Page<SensorData> page = new Page<>(1, limit);
        LambdaQueryWrapper<SensorData> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SensorData::getPointId, pointId)
                .orderByDesc(SensorData::getRecordedAt);
        return sensorDataMapper.selectPage(page, wrapper).getRecords().stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    public Page<EnvironmentDataDTO> getHistoryDataPaged(Long pointId, int pageNum, int pageSize) {
        Page<SensorData> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<SensorData> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(SensorData::getPointId, pointId)
                .orderByDesc(SensorData::getRecordedAt);
        Page<SensorData> dataPage = sensorDataMapper.selectPage(page, wrapper);

        Page<EnvironmentDataDTO> dtoPage = new Page<>(pageNum + 1, pageSize);
        dtoPage.setTotal(dataPage.getTotal());
        dtoPage.setRecords(dataPage.getRecords().stream().map(this::toDTO).collect(Collectors.toList()));
        return dtoPage;
    }

    public List<EnvironmentDataDTO> getHistoryDataByTimeRange(Long pointId, LocalDateTime startTime, LocalDateTime endTime) {
        return sensorDataMapper.findByPointIdAndTimeRange(pointId, startTime, endTime).stream()
                .map(this::toDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public EnvironmentDataDTO saveData(EnvironmentDataDTO dto) {
        SensorData data = new SensorData();
        data.setPointId(dto.getPointId());
        data.setTemperature(dto.getTemperature());
        data.setHumidity(dto.getHumidity());
        data.setLight(dto.getLight());
        data.setCo2(dto.getCo2());
        data.setSoilMoisture(dto.getSoilMoisture());
        data.setRecordedAt(dto.getRecordedAt() != null ? dto.getRecordedAt() : LocalDateTime.now());

        sensorDataMapper.insert(data);
        checkAndCreateAlarms(data);

        EnvironmentDataDTO saved = toDTO(data);
        environmentCacheService.put(data.getPointId(), saved);
        return saved;
    }

    private void checkAndCreateAlarms(SensorData data) {
        Long pointId = data.getPointId();

        // One query for existing unprocessed alarm types per point.
        Set<String> existingUnprocessedTypes = new HashSet<>(alarmMapper.findUnprocessedAlarmTypesByPointId(pointId));
        List<Alarm> alarmsToCreate = new ArrayList<>();

        if (data.getTemperature() != null) {
            if (data.getTemperature().compareTo(TEMP_MAX) > 0) {
                addAlarmIfNeeded(pointId, "TEMPERATURE_HIGH", data.getTemperature(), TEMP_MAX, existingUnprocessedTypes, alarmsToCreate);
            } else if (data.getTemperature().compareTo(TEMP_MIN) < 0) {
                addAlarmIfNeeded(pointId, "TEMPERATURE_LOW", data.getTemperature(), TEMP_MIN, existingUnprocessedTypes, alarmsToCreate);
            }
        }

        if (data.getHumidity() != null) {
            if (data.getHumidity().compareTo(HUMIDITY_MAX) > 0) {
                addAlarmIfNeeded(pointId, "HUMIDITY_HIGH", data.getHumidity(), HUMIDITY_MAX, existingUnprocessedTypes, alarmsToCreate);
            } else if (data.getHumidity().compareTo(HUMIDITY_MIN) < 0) {
                addAlarmIfNeeded(pointId, "HUMIDITY_LOW", data.getHumidity(), HUMIDITY_MIN, existingUnprocessedTypes, alarmsToCreate);
            }
        }

        if (data.getLight() != null && data.getLight().compareTo(LIGHT_MIN) < 0) {
            addAlarmIfNeeded(pointId, "LIGHT_LOW", data.getLight(), LIGHT_MIN, existingUnprocessedTypes, alarmsToCreate);
        }

        if (data.getCo2() != null && data.getCo2().compareTo(CO2_MAX) > 0) {
            addAlarmIfNeeded(pointId, "CO2_HIGH", data.getCo2(), CO2_MAX, existingUnprocessedTypes, alarmsToCreate);
        }

        if (data.getSoilMoisture() != null && data.getSoilMoisture().compareTo(SOIL_MOISTURE_MIN) < 0) {
            addAlarmIfNeeded(pointId, "SOIL_MOISTURE_LOW", data.getSoilMoisture(), SOIL_MOISTURE_MIN, existingUnprocessedTypes, alarmsToCreate);
        }

        for (Alarm alarm : alarmsToCreate) {
            alarmMapper.insert(alarm);
            log.warn("创建报警: 检测点={}, 类型={}, 值={}, 阈值={}",
                    alarm.getPointId(), alarm.getAlarmType(), alarm.getAlarmValue(), alarm.getThreshold());
        }
    }

    private void addAlarmIfNeeded(Long pointId, String alarmType, BigDecimal alarmValue, BigDecimal threshold,
                                  Set<String> existingUnprocessedTypes, List<Alarm> alarmsToCreate) {
        if (existingUnprocessedTypes.contains(alarmType)) {
            return;
        }

        Alarm alarm = new Alarm();
        alarm.setPointId(pointId);
        alarm.setAlarmType(alarmType);
        alarm.setAlarmValue(alarmValue);
        alarm.setThreshold(threshold);
        alarm.setStatus(0);

        alarmsToCreate.add(alarm);
        existingUnprocessedTypes.add(alarmType);
    }

    @Transactional
    public void cleanOldData(int daysToKeep) {
        LocalDateTime cutoffTime = LocalDateTime.now().minusDays(daysToKeep);
        sensorDataMapper.deleteByRecordedAtBefore(cutoffTime);
        log.info("清理{}天前的传感器数据", daysToKeep);
    }

    private EnvironmentDataDTO toDTO(SensorData data) {
        EnvironmentDataDTO dto = new EnvironmentDataDTO();
        dto.setId(data.getId());
        dto.setPointId(data.getPointId());
        dto.setTemperature(data.getTemperature());
        dto.setHumidity(data.getHumidity());
        dto.setLight(data.getLight());
        dto.setCo2(data.getCo2());
        dto.setSoilMoisture(data.getSoilMoisture());
        dto.setRecordedAt(data.getRecordedAt());
        dto.setCreatedAt(data.getCreatedAt());
        return dto;
    }
}
