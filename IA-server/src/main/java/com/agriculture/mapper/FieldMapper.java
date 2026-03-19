package com.agriculture.mapper;

import com.agriculture.entity.Field;
import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Select;

import java.util.List;

@Mapper
public interface FieldMapper extends BaseMapper<Field> {

    @Select("SELECT * FROM field WHERE status = #{status}")
    List<Field> findByStatus(Integer status);

    @Select("SELECT * FROM field WHERE field_id = #{fieldId}")
    Field findByFieldId(String fieldId);

    @Select("SELECT COUNT(*) > 0 FROM field WHERE field_id = #{fieldId}")
    boolean existsByFieldId(String fieldId);
}
