package com.agriculture.common.enums;

import lombok.AllArgsConstructor;
import lombok.Getter;

@Getter
@AllArgsConstructor
public enum AlarmType {

    TEMPERATURE_HIGH("TEMPERATURE_HIGH", "高温报警"),
    TEMPERATURE_LOW("TEMPERATURE_LOW", "低温报警"),
    HUMIDITY_HIGH("HUMIDITY_HIGH", "湿度过高"),
    HUMIDITY_LOW("HUMIDITY_LOW", "湿度过低"),
    LIGHT_LOW("LIGHT_LOW", "光照不足"),
    CO2_HIGH("CO2_HIGH", "CO2超标"),
    SOIL_MOISTURE_LOW("SOIL_MOISTURE_LOW", "土壤湿度过低");

    private final String code;
    private final String description;

    public static AlarmType fromCode(String code) {
        for (AlarmType type : values()) {
            if (type.code.equals(code)) {
                return type;
            }
        }
        throw new IllegalArgumentException("未知的报警类型: " + code);
    }
}
