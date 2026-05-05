package com.agriculture.service;

import com.agriculture.model.dto.WeatherDTO;

public interface WeatherService {

    WeatherDTO getWeatherByLocation(Double latitude, Double longitude);
}
