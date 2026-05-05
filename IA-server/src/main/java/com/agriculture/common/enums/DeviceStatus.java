package com.agriculture.common.enums;

import com.baomidou.mybatisplus.annotation.EnumValue;
import com.fasterxml.jackson.annotation.JsonValue;
import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum DeviceStatus {

    OFFLINE(0, "离线"),
    ONLINE(1, "在线"),
    WORKING(2, "工作中"),
    FAULT(3, "故障");

    @EnumValue
    private final int code;

    @JsonValue
    private final String description;

    public static DeviceStatus fromCode(int code) {
        for (DeviceStatus status : values()) {
            if (status.code == code) {
                return status;
            }
        }
        throw new IllegalArgumentException("未知的设备状态码: " + code);
    }
}
