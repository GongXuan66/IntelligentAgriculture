package com.agriculture.service.impl;

import com.agriculture.common.converter.AlarmConverter;
import com.agriculture.common.exception.InvalidOperationException;
import com.agriculture.common.exception.ResourceNotFoundException;
import com.agriculture.model.dto.AlarmDTO;
import com.agriculture.entity.Alarm;
import com.agriculture.mapper.AlarmMapper;
import com.agriculture.service.AlarmService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

@Slf4j
@Service
@RequiredArgsConstructor
public class AlarmServiceImpl implements AlarmService {

    private final AlarmMapper alarmMapper;
    private final AlarmConverter alarmConverter;

    @Override
    public List<AlarmDTO> getAllAlarms() {
        return alarmMapper.findAllByOrderByCreatedAtDesc().stream()
                .map(alarmConverter::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public Page<AlarmDTO> getAlarmsPaged(int pageNum, int pageSize) {
        Page<Alarm> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<Alarm> wrapper = new LambdaQueryWrapper<>();
        wrapper.orderByDesc(Alarm::getCreatedAt);
        Page<Alarm> alarmPage = alarmMapper.selectPage(page, wrapper);

        Page<AlarmDTO> dtoPage = new Page<>(pageNum + 1, pageSize);
        dtoPage.setTotal(alarmPage.getTotal());
        dtoPage.setRecords(alarmPage.getRecords().stream().map(alarmConverter::toDTO).collect(Collectors.toList()));
        return dtoPage;
    }

    @Override
    public List<AlarmDTO> getAlarmsByPointId(Long pointId) {
        return alarmMapper.findByPointIdOrderByCreatedAtDesc(pointId).stream()
                .map(alarmConverter::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public List<AlarmDTO> getUnprocessedAlarms() {
        return alarmMapper.findByStatusOrderByCreatedAtDesc(0).stream()
                .map(alarmConverter::toDTO)
                .collect(Collectors.toList());
    }

    @Override
    public Page<AlarmDTO> getUnprocessedAlarmsPaged(int pageNum, int pageSize) {
        Page<Alarm> page = new Page<>(pageNum + 1, pageSize);
        LambdaQueryWrapper<Alarm> wrapper = new LambdaQueryWrapper<>();
        wrapper.eq(Alarm::getStatus, 0)
                .orderByDesc(Alarm::getCreatedAt);
        Page<Alarm> alarmPage = alarmMapper.selectPage(page, wrapper);

        Page<AlarmDTO> dtoPage = new Page<>(pageNum + 1, pageSize);
        dtoPage.setTotal(alarmPage.getTotal());
        dtoPage.setRecords(alarmPage.getRecords().stream().map(alarmConverter::toDTO).collect(Collectors.toList()));
        return dtoPage;
    }

    @Override
    public Long getUnprocessedCount() {
        return alarmMapper.countUnprocessed();
    }

    @Override
    public Long getUnprocessedCountByPointId(Long pointId) {
        return alarmMapper.countUnprocessedByPointId(pointId);
    }

    @Override
    public AlarmDTO getAlarmById(Long id) {
        Alarm alarm = alarmMapper.selectById(id);
        return alarm != null ? alarmConverter.toDTO(alarm) : null;
    }

    @Override
    @Transactional
    public AlarmDTO handleAlarm(Long id, String remark) {
        Alarm alarm = alarmMapper.selectById(id);
        if (alarm == null) {
            throw new ResourceNotFoundException("报警记录", id);
        }

        if (alarm.getStatus() == 1) {
            throw new InvalidOperationException("报警已处理");
        }

        alarm.setStatus(1);
        alarm.setHandledAt(LocalDateTime.now());

        alarmMapper.updateById(alarm);
        log.info("处理报警: ID={}, 类型={}", id, alarm.getAlarmType());

        return alarmConverter.toDTO(alarm);
    }

    @Override
    @Transactional
    public void handleAllByPointId(Long pointId) {
        LocalDateTime now = LocalDateTime.now();
        int affected = alarmMapper.handleAllByPointId(pointId, now);
        log.info("处理检测点{}的所有未处理报警, 共{}条", pointId, affected);
    }

    @Override
    @Transactional
    public void deleteAlarm(Long id) {
        alarmMapper.deleteById(id);
    }
}
