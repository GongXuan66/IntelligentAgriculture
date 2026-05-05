package com.agriculture.service.impl;

import com.agriculture.common.exception.BusinessException;
import com.agriculture.model.dto.WeatherDTO;
import com.agriculture.service.WeatherService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@Service
@Slf4j
public class WeatherServiceImpl implements WeatherService {

    @Value("${weather.qweather.api-key:}")
    private String apiKey;

    @Value("${weather.qweather.api-host:devapi.qweather.com}")
    private String apiHost;

    @Value("${weather.qweather.geo-host:geoapi.qweather.com}")
    private String geoApiHost;

    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Override
    @Cacheable(value = "weather", key = "#latitude.toString() + '_' + #longitude.toString()", unless = "#result == null")
    public WeatherDTO getWeatherByLocation(Double latitude, Double longitude) {
        checkApiKey();

        try {
            String locationId = getLocationIdByCoords(latitude, longitude);
            if (locationId == null) {
                throw new BusinessException(502, "无法识别该位置");
            }

            log.info("位置查询成功: 经纬度 ({}, {}) -> 城市ID {}", latitude, longitude, locationId);
            return fetchWeatherByLocationId(locationId, latitude, longitude);
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("获取天气失败", e);
            throw new BusinessException(502, "获取天气失败: " + e.getMessage());
        }
    }

    private void checkApiKey() {
        if (apiKey == null || apiKey.isEmpty()) {
            throw new BusinessException(500, "天气服务未配置API Key，请联系管理员配置和风天气API");
        }
    }

    private String getLocationIdByCoords(Double latitude, Double longitude) {
        try {
            String location = String.format("%.2f,%.2f", longitude, latitude);

            String url = UriComponentsBuilder.newInstance()
                    .scheme("https")
                    .path("geo/v2/city/lookup")
                    .queryParam("location", location)
                    .queryParam("key", apiKey)
                    .build()
                    .toUriString();

            log.info("请求城市查询: {}", url);
            String response = restTemplate.getForObject(url, String.class);
            JsonNode root = objectMapper.readTree(response);

            String code = root.path("code").asText();
            if (!"200".equals(code)) {
                log.error("城市查询失败: code={}", code);
                return null;
            }

            JsonNode locationNode = root.path("location");
            if (locationNode.isArray() && locationNode.size() > 0) {
                JsonNode first = locationNode.get(0);
                return first.path("id").asText();
            }

            return null;
        } catch (Exception e) {
            log.error("城市查询请求失败", e);
            return null;
        }
    }

    private WeatherDTO fetchWeatherByLocationId(String locationId, Double latitude, Double longitude) {
        try {
            String nowUrl = UriComponentsBuilder.newInstance()
                    .scheme("https")
                    .host(apiHost)
                    .path("/v7/weather/now")
                    .queryParam("location", locationId)
                    .queryParam("key", apiKey)
                    .build()
                    .toUriString();

            String nowResponse = restTemplate.getForObject(nowUrl, String.class);
            JsonNode nowRoot = objectMapper.readTree(nowResponse);
            String code = nowRoot.path("code").asText();

            if (!"200".equals(code)) {
                log.error("天气API返回错误: {}", code);
                throw new BusinessException(502, "天气API错误: " + code);
            }

            JsonNode now = nowRoot.path("now");
            WeatherDTO weather = new WeatherDTO();
            weather.setTemp(parseDouble(now.path("temp").asText()));
            weather.setFeelsLike(parseDouble(now.path("feelsLike").asText()));
            weather.setText(now.path("text").asText());
            weather.setIcon(now.path("icon").asText());
            weather.setHumidity(parseInt(now.path("humidity").asText()));
            weather.setWindDir(now.path("windDir").asText());
            weather.setWindSpeed(parseDouble(now.path("windSpeed").asText()));
            weather.setPressure(parseInt(now.path("pressure").asText()));
            weather.setVisibility(parseDouble(now.path("vis").asText()));
            weather.setUpdateTime(now.path("obsTime").asText());

            weather.setLocationId(locationId);
            weather.setLatitude(latitude);
            weather.setLongitude(longitude);

            LocationInfo locInfo = getCityName(locationId);
            if (locInfo != null) {
                weather.setLocation(locInfo.getName());
                weather.setCity(locInfo.getCity());
                weather.setProvince(locInfo.getProvince());
            }

            weather.setForecast(fetchForecast(locationId));
            return weather;
        } catch (BusinessException e) {
            throw e;
        } catch (Exception e) {
            log.error("获取天气数据失败", e);
            throw new BusinessException(502, "获取天气数据失败: " + e.getMessage());
        }
    }

    private LocationInfo getCityName(String locationId) {
        try {
            String url = UriComponentsBuilder.newInstance()
                    .scheme("https")
                    .host(geoApiHost)
                    .path("/v2/city/lookup")
                    .queryParam("location", locationId)
                    .queryParam("key", apiKey)
                    .build()
                    .toUriString();

            String response = restTemplate.getForObject(url, String.class);
            JsonNode root = objectMapper.readTree(response);

            if ("200".equals(root.path("code").asText())) {
                JsonNode locationNode = root.path("location");
                if (locationNode.isArray() && locationNode.size() > 0) {
                    JsonNode first = locationNode.get(0);
                    LocationInfo info = new LocationInfo();
                    info.setName(first.path("name").asText());
                    info.setCity(first.path("name").asText());
                    info.setProvince(first.path("adm1").asText());
                    return info;
                }
            }
        } catch (Exception e) {
            log.warn("获取城市名称失败", e);
        }
        return null;
    }

    private List<WeatherDTO.ForecastDTO> fetchForecast(String locationId) {
        try {
            String forecastUrl = UriComponentsBuilder.newInstance()
                    .scheme("https")
                    .host(apiHost)
                    .path("/v7/weather/3d")
                    .queryParam("location", locationId)
                    .queryParam("key", apiKey)
                    .build()
                    .toUriString();

            String response = restTemplate.getForObject(forecastUrl, String.class);
            JsonNode root = objectMapper.readTree(response);

            if (!"200".equals(root.path("code").asText())) {
                return new ArrayList<>();
            }

            List<WeatherDTO.ForecastDTO> forecast = new ArrayList<>();
            JsonNode daily = root.path("daily");
            for (int i = 0; i < Math.min(3, daily.size()); i++) {
                JsonNode day = daily.get(i);
                WeatherDTO.ForecastDTO dto = new WeatherDTO.ForecastDTO();
                dto.setDate(formatDate(day.path("fxDate").asText()));
                dto.setTempMax(parseInt(day.path("tempMax").asText()));
                dto.setTempMin(parseInt(day.path("tempMin").asText()));
                dto.setTextDay(day.path("textDay").asText());
                dto.setTextNight(day.path("textNight").asText());
                dto.setIconDay(day.path("iconDay").asText());
                dto.setIconNight(day.path("iconNight").asText());
                forecast.add(dto);
            }
            return forecast;
        } catch (Exception e) {
            log.warn("获取天气预报失败", e);
            return new ArrayList<>();
        }
    }

    private Double parseDouble(String value) {
        try { return Double.parseDouble(value); } catch (Exception e) { return 0.0; }
    }

    private Integer parseInt(String value) {
        try { return Integer.parseInt(value); } catch (Exception e) { return 0; }
    }

    private String formatDate(String date) {
        try {
            LocalDate d = LocalDate.parse(date);
            return d.format(DateTimeFormatter.ofPattern("MM-dd"));
        } catch (Exception e) {
            return date;
        }
    }

    private static class LocationInfo {
        private String name;
        private String city;
        private String province;

        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getCity() { return city; }
        public void setCity(String city) { this.city = city; }
        public String getProvince() { return province; }
        public void setProvince(String province) { this.province = province; }
    }
}
