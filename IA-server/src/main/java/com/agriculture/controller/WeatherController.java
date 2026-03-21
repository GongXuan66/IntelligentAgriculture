package com.agriculture.controller;

import com.agriculture.model.dto.WeatherDTO;
import com.agriculture.model.response.ApiResponse;
import com.agriculture.service.WeatherService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.tags.Tag;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.web.bind.annotation.*;

/**
 * 天气接口
 */
@RestController
@RequestMapping("/weather")
@RequiredArgsConstructor
@Slf4j
@Tag(name = "天气管理", description = "天气信息查询接口")
public class WeatherController {

    private final WeatherService weatherService;

    /**
     * 根据经纬度获取天气
     * @param latitude 纬度
     * @param longitude 经度
     */
    @GetMapping("/current")
    @Operation(summary = "获取当前天气", description = "根据经纬度获取天气信息，包含3天预报")
    public ApiResponse<WeatherDTO> getCurrentWeather(
            @Parameter(description = "纬度", required = true) 
            @RequestParam Double latitude,
            @Parameter(description = "经度", required = true) 
            @RequestParam Double longitude) {
        try {
            WeatherDTO weather = weatherService.getWeatherByLocation(latitude, longitude);
            return ApiResponse.success(weather);
        } catch (RuntimeException e) {
            log.error("获取天气失败", e);
            return ApiResponse.error(e.getMessage());
        }
    }
}