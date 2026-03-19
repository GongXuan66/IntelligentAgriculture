package com.agriculture.mapper;

import com.agriculture.entity.IrrigationLog;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface IrrigationLogMapper extends BaseMapper<IrrigationLog> {

    @Select("SELECT * FROM irrigation_log WHERE point_id = #{pointId} ORDER BY start_time DESC")
    List<IrrigationLog> findByPointIdOrderByStartTimeDesc(Long pointId);

    @Select("SELECT * FROM irrigation_log WHERE point_id = #{pointId} ORDER BY start_time DESC LIMIT 1")
    IrrigationLog findFirstByPointIdOrderByStartTimeDesc(Long pointId);

    @Select("SELECT * FROM irrigation_log WHERE point_id = #{pointId} AND mode = 0 ORDER BY start_time DESC LIMIT 1")
    IrrigationLog findLastAutoByPointId(Long pointId);

    @Select("SELECT * FROM irrigation_log WHERE point_id = #{pointId} AND end_time IS NULL ORDER BY start_time DESC LIMIT 1")
    IrrigationLog findActiveByPointId(Long pointId);

    @Select("SELECT * FROM irrigation_log WHERE point_id = #{pointId} " +
            "AND start_time BETWEEN #{startTime} AND #{endTime} ORDER BY start_time DESC")
    List<IrrigationLog> findByPointIdAndTimeRange(
            @Param("pointId") Long pointId,
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    @Select("SELECT SUM(water_amount) FROM irrigation_log WHERE point_id = #{pointId}")
    Double sumWaterAmountByPointId(@Param("pointId") Long pointId);
}
