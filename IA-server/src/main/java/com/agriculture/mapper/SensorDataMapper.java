package com.agriculture.mapper;

import com.agriculture.entity.SensorData;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Delete;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface SensorDataMapper extends BaseMapper<SensorData> {

    @Select("SELECT * FROM sensor_data WHERE point_id = #{pointId} ORDER BY recorded_at DESC")
    List<SensorData> findByPointIdOrderByRecordedAtDesc(Long pointId);

    @Select("SELECT * FROM sensor_data WHERE point_id = #{pointId} ORDER BY recorded_at DESC LIMIT 1")
    SensorData findFirstByPointIdOrderByRecordedAtDesc(Long pointId);

    @Select("SELECT * FROM sensor_data WHERE point_id = #{pointId} " +
            "AND recorded_at BETWEEN #{startTime} AND #{endTime} ORDER BY recorded_at DESC")
    List<SensorData> findByPointIdAndTimeRange(
            @Param("pointId") Long pointId,
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    @Delete("DELETE FROM sensor_data WHERE recorded_at < #{time}")
    void deleteByRecordedAtBefore(LocalDateTime time);
}
