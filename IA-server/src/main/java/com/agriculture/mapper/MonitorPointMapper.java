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

    @Select("SELECT * FROM monitor_point WHERE point_code = #{pointCode}")
    MonitorPoint findByPointCode(String pointCode);

    @Select("SELECT * FROM monitor_point WHERE farm_id = #{farmId} AND status = 1")
    List<MonitorPoint> findByFarmId(Long farmId);
}