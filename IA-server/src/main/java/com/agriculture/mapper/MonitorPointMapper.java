package com.agriculture.mapper;

import com.agriculture.entity.MonitorPoint;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface MonitorPointMapper extends BaseMapper<MonitorPoint> {

    @Select("SELECT * FROM monitor_point WHERE status = #{status}")
    List<MonitorPoint> findByStatus(Integer status);

    @Select("SELECT * FROM monitor_point WHERE point_id = #{pointId}")
    MonitorPoint findByPointId(String pointId);

    @Select("SELECT COUNT(*) > 0 FROM monitor_point WHERE point_id = #{pointId}")
    boolean existsByPointId(String pointId);
}
