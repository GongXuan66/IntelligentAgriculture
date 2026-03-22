package com.agriculture.mapper;

import com.agriculture.entity.Device;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface DeviceMapper extends BaseMapper<Device> {

    @Select("SELECT * FROM device WHERE point_id = #{pointId}")
    List<Device> findByPointId(Long pointId);

    @Select("SELECT * FROM device WHERE device_type = #{deviceType}")
    List<Device> findByDeviceType(String deviceType);

    @Select("SELECT * FROM device WHERE point_id = #{pointId} AND status = #{status}")
    List<Device> findByPointIdAndStatus(Long pointId, Integer status);

    @Select("SELECT * FROM device WHERE device_code = #{deviceCode}")
    Device findByDeviceCode(String deviceCode);

    @Select("SELECT COUNT(*) > 0 FROM device WHERE device_code = #{deviceCode}")
    boolean existsByDeviceCode(String deviceCode);
}
