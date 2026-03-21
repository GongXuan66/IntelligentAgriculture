package com.agriculture.model.dto;

import lombok.Data;
import java.util.List;

/**
 * 天气数据传输对象
 */
@Data
public class WeatherDTO {
    // 当前天气
    private Double temp;           // 温度
    private Double feelsLike;      // 体感温度
    private String text;           // 天气状况文字
    private String icon;           // 天气图标代码
    private Integer humidity;      // 湿度百分比
    private String windDir;        // 风向
    private Double windSpeed;      // 风速 km/h
    private Integer pressure;      // 气压
    private Double visibility;     // 能见度 km
    private String updateTime;     // 更新时间
    
    // 位置信息
    private String location;       // 位置名称
    private String locationId;     // 位置ID
    private String province;       // 省份
    private String city;           // 城市
    private Double latitude;       // 纬度
    private Double longitude;      // 经度
    
    // 未来预报
    private List<ForecastDTO> forecast;

    /**
     * 天气预报
     */
    @Data
    public static class ForecastDTO {
        private String date;           // 日期
        private Integer tempMax;       // 最高温度
        private Integer tempMin;       // 最低温度
        private String textDay;        // 白天天气
        private String textNight;      // 夜间天气
        private String iconDay;        // 白天图标
        private String iconNight;      // 夜间图标
    }
}
