package com.agriculture.mapper;

import com.agriculture.entity.CropPlanting;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

/**
 * 作物种植信息 Mapper 接口
 */
@Mapper
public interface CropPlantingMapper extends BaseMapper<CropPlanting> {
}
