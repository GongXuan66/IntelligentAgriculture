package com.agriculture.service;

import com.agriculture.model.dto.FarmDTO;
import com.agriculture.model.dto.MonitorPointDTO;

import java.util.List;

public interface FarmService {

    List<FarmDTO> getAllFarms();

    List<FarmDTO> getFarmsByUserId(Long userId);

    List<FarmDTO> getActiveFarms();

    FarmDTO.DetailResponse getFarmDetail(Long id);

    FarmDTO getFarmById(Long id);

    List<MonitorPointDTO> getPointsByFarmId(Long farmId);

    FarmDTO createFarm(FarmDTO.CreateRequest request);

    FarmDTO updateFarm(Long id, FarmDTO.UpdateRequest request);

    void deleteFarm(Long id);
}
