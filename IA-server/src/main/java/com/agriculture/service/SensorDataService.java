package com.agriculture.service;

import com.agriculture.model.dto.EnvironmentDataDTO;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;

import java.time.LocalDateTime;
import java.util.List;

public interface SensorDataService {

    EnvironmentDataDTO getCurrentData(Long pointId);

    List<EnvironmentDataDTO> getHistoryData(Long pointId, int limit);

    Page<EnvironmentDataDTO> getHistoryDataPaged(Long pointId, int pageNum, int pageSize);

    List<EnvironmentDataDTO> getHistoryDataByTimeRange(Long pointId, LocalDateTime startTime, LocalDateTime endTime);

    EnvironmentDataDTO saveData(EnvironmentDataDTO dto);

    void cleanOldData(int daysToKeep);
}
