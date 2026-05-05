package com.agriculture.service;

import com.agriculture.model.dto.AlarmDTO;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;

import java.util.List;

public interface AlarmService {

    List<AlarmDTO> getAllAlarms();

    Page<AlarmDTO> getAlarmsPaged(int pageNum, int pageSize);

    List<AlarmDTO> getAlarmsByPointId(Long pointId);

    List<AlarmDTO> getUnprocessedAlarms();

    Page<AlarmDTO> getUnprocessedAlarmsPaged(int pageNum, int pageSize);

    Long getUnprocessedCount();

    Long getUnprocessedCountByPointId(Long pointId);

    AlarmDTO getAlarmById(Long id);

    AlarmDTO handleAlarm(Long id, String remark);

    void handleAllByPointId(Long pointId);

    void deleteAlarm(Long id);
}
