package com.agriculture.mapper;

import com.agriculture.entity.Alarm;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;
import org.apache.ibatis.annotations.Update;

import java.time.LocalDateTime;
import java.util.List;

@Mapper
public interface AlarmMapper extends BaseMapper<Alarm> {

    @Select("SELECT * FROM alarm WHERE point_id = #{pointId} ORDER BY created_at DESC")
    List<Alarm> findByPointIdOrderByCreatedAtDesc(Long pointId);

    @Select("SELECT * FROM alarm WHERE status = #{status} ORDER BY created_at DESC")
    List<Alarm> findByStatusOrderByCreatedAtDesc(Integer status);

    @Select("SELECT * FROM alarm WHERE point_id = #{pointId} AND status = #{status} ORDER BY created_at DESC")
    List<Alarm> findByPointIdAndStatus(@Param("pointId") Long pointId, @Param("status") Integer status);

    @Select("SELECT DISTINCT alarm_type FROM alarm WHERE point_id = #{pointId} AND status = 0")
    List<String> findUnprocessedAlarmTypesByPointId(@Param("pointId") Long pointId);

    @Select("SELECT COUNT(*) FROM alarm WHERE status = 0")
    Long countUnprocessed();

    @Select("SELECT COUNT(*) FROM alarm WHERE point_id = #{pointId} AND status = 0")
    Long countUnprocessedByPointId(Long pointId);

    @Select("SELECT * FROM alarm WHERE created_at BETWEEN #{startTime} AND #{endTime} ORDER BY created_at DESC")
    List<Alarm> findByTimeRange(
            @Param("startTime") LocalDateTime startTime,
            @Param("endTime") LocalDateTime endTime);

    @Select("SELECT * FROM alarm ORDER BY created_at DESC")
    List<Alarm> findAllByOrderByCreatedAtDesc();

    @Update("UPDATE alarm SET status = 1, handled_at = #{handledAt} WHERE point_id = #{pointId} AND status = 0")
    int handleAllByPointId(@Param("pointId") Long pointId, @Param("handledAt") LocalDateTime handledAt);
}
