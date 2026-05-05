package com.agriculture.common.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;
import com.fasterxml.jackson.annotation.JsonValue;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum EntityStatus {

    DISABLED(0, "停用"),
    ENABLED(1, "启用");

    @EnumValue
    private final int code;

    @JsonValue
    private final String description;

    public static EntityStatus fromCode(int code) {
        for (EntityStatus status : values()) {
            if (status.code == code) {
                return status;
            }
        }
        throw new IllegalArgumentException("未知的状态码: " + code);
    }
}
