package com.agriculture.service;

import com.agriculture.model.dto.MonitorPointDTO;

import java.util.List;

public interface MonitorPointService {

    List<MonitorPointDTO> getAllPoints();

    List<MonitorPointDTO> getActivePoints();

    List<MonitorPointDTO> getPointsByFarmId(Long farmId);

    MonitorPointDTO getPointById(Long id);

    MonitorPointDTO getPointByPointCode(String pointCode);

    MonitorPointDTO getPointByPointId(String pointId);

    List<MonitorPointDTO> getPointsByFieldId(Long fieldId);

    MonitorPointDTO createPoint(MonitorPointDTO.CreateRequest request);

    MonitorPointDTO updatePoint(Long id, MonitorPointDTO.UpdateRequest request);

    void deletePoint(Long id);
}
