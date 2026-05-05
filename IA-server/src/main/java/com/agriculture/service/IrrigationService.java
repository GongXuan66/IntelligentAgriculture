package com.agriculture.service;

import com.agriculture.model.dto.EnvironmentDataDTO;
import com.agriculture.model.dto.IrrigationDTO;
import com.agriculture.model.request.AutoIrrigationRequest;
import com.agriculture.model.request.IrrigationPlanConfig;
import com.agriculture.model.request.IrrigationPlanRequest;
import com.agriculture.model.response.AutoIrrigationPlanResponse;
import com.agriculture.model.response.AutoIrrigationResultResponse;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;

import java.util.List;

public interface IrrigationService {

    List<IrrigationDTO> getLogsByPointId(Long pointId);

    Page<IrrigationDTO> getLogsPaged(Long pointId, int pageNum, int pageSize);

    IrrigationDTO getLatestLog(Long pointId);

    Double getTotalWaterAmount(Long pointId);

    IrrigationDTO startIrrigation(IrrigationDTO.StartRequest request);

    IrrigationDTO stopIrrigation(Long logId);

    void deleteLog(Long id);

    AutoIrrigationPlanResponse buildAutoPlan(EnvironmentDataDTO envData, IrrigationPlanConfig config);

    AutoIrrigationPlanResponse buildAutoPlan(IrrigationPlanRequest request);

    AutoIrrigationResultResponse startAutoIrrigation(AutoIrrigationRequest request);
}
