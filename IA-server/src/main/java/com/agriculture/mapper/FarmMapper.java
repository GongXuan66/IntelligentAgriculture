package com.agriculture.mapper;

import com.agriculture.entity.Farm;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;

/**
 * 农场 Mapper 接口
 */
@Mapper
public interface FarmMapper extends BaseMapper<Farm> {
}
