package com.agriculture.common.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;
import com.fasterxml.jackson.annotation.JsonValue;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum AlarmStatus {

    UNPROCESSED(0, "未处理"),
    PROCESSED(1, "已处理"),
    IGNORED(2, "已忽略");

    @EnumValue
    private final int code;

    @JsonValue
    private final String description;

    public static AlarmStatus fromCode(int code) {
        for (AlarmStatus status : values()) {
            if (status.code == code) {
                return status;
            }
        }
        throw new IllegalArgumentException("未知的报警状态码: " + code);
    }
}
