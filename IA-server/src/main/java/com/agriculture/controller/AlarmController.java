package com.agriculture.controller;

import com.agriculture.model.dto.AlarmDTO;
import com.agriculture.model.response.ApiResponse;
import com.agriculture.service.AlarmService;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * 报警管理接口
 */
@RestController
@RequestMapping("/alarm")
@RequiredArgsConstructor
@Slf4j
public class AlarmController {

    private final AlarmService alarmService;

    /**
     * 获取报警列表
     */
    @GetMapping("/list")
    public ApiResponse<List<AlarmDTO>> getAlarmList(
            @RequestParam(required = false) Long pointId,
            @RequestParam(required = false) Integer status) {
        List<AlarmDTO> alarms;

        if (pointId != null) {
            alarms = alarmService.getAlarmsByPointId(pointId);
        } else if (status != null) {
            alarms = alarmService.getUnprocessedAlarms();
        } else {
            alarms = alarmService.getAllAlarms();
        }

        return ApiResponse.success(alarms);
    }

    /**
     * 分页获取报警列表
     */
    @GetMapping("/list/paged")
    public ApiResponse<Page<AlarmDTO>> getAlarmsPaged(
            @RequestParam(required = false, defaultValue = "0") int page,
            @RequestParam(required = false, defaultValue = "10") int size) {
        Page<AlarmDTO> alarms = alarmService.getAlarmsPaged(page, size);
        return ApiResponse.success(alarms);
    }

    /**
     * 获取未处理报警数量
     */
    @GetMapping("/unprocessed/count")
    public ApiResponse<Long> getUnprocessedCount(
            @RequestParam(required = false) Long pointId) {
        Long count;
        if (pointId != null) {
            count = alarmService.getUnprocessedCountByPointId(pointId);
        } else {
            count = alarmService.getUnprocessedCount();
        }
        return ApiResponse.success(count);
    }

    /**
     * 获取报警详情
     */
    @GetMapping("/{id}")
    public ApiResponse<AlarmDTO> getAlarmById(@PathVariable Long id) {
        AlarmDTO alarm = alarmService.getAlarmById(id);
        if (alarm == null) {
            return ApiResponse.error("报警记录不存在");
        }
        return ApiResponse.success(alarm);
    }

    /**
     * 处理报警
     */
    @PutMapping("/{id}/handle")
    public ApiResponse<AlarmDTO> handleAlarm(
            @PathVariable Long id,
            @RequestBody(required = false) AlarmDTO.HandleRequest request) {
        try {
            String remark = request != null ? request.getRemark() : null;
            AlarmDTO alarm = alarmService.handleAlarm(id, remark);
            return ApiResponse.success("处理成功", alarm);
        } catch (RuntimeException e) {
            return ApiResponse.error(e.getMessage());
        }
    }

    /**
     * 处理检测点所有报警
     */
    @PutMapping("/handle-all")
    public ApiResponse<Void> handleAllByPointId(@RequestParam Long pointId) {
        alarmService.handleAllByPointId(pointId);
        return ApiResponse.success("已处理所有报警", null);
    }

    /**
     * 删除报警记录
     */
    @DeleteMapping("/{id}")
    public ApiResponse<Void> deleteAlarm(@PathVariable Long id) {
        alarmService.deleteAlarm(id);
        return ApiResponse.success("删除成功", null);
    }
}
