package com.agriculture.mapper;

import com.agriculture.entity.CropStageConfig;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface CropStageConfigMapper extends BaseMapper<CropStageConfig> {

    @Select("SELECT * FROM crop_stage_config WHERE crop_code = #{cropCode} ORDER BY stage_order")
    List<CropStageConfig> findByCropCode(@Param("cropCode") String cropCode);

    @Select("SELECT * FROM crop_stage_config WHERE crop_code = #{cropCode} " +
            "AND start_day <= #{days} AND end_day >= #{days}")
    CropStageConfig findByCropCodeAndDay(@Param("cropCode") String cropCode, @Param("days") int days);
}