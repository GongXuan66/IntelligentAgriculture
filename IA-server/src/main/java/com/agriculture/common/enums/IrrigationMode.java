package com.agriculture.common.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;
import com.fasterxml.jackson.annotation.JsonValue;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum IrrigationMode {

    AUTO(0, "自动"),
    MANUAL(1, "手动");

    @EnumValue
    private final int code;

    @JsonValue
    private final String description;

    public static IrrigationMode fromCode(int code) {
        for (IrrigationMode mode : values()) {
            if (mode.code == code) {
                return mode;
            }
        }
        throw new IllegalArgumentException("未知的灌溉模式码: " + code);
    }
}
