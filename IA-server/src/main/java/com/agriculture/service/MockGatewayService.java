package com.agriculture.service;

import com.agriculture.model.dto.EnvironmentDataDTO;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.Random;

/**
 * 模拟网关服务 - 定时生成环境数据
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class MockGatewayService {

    private final SensorDataService sensorDataService;
    private final Random random = new Random();

    // 是否启用模拟
    private boolean enabled = false;

    // 模拟的检测点ID
    private Long mockPointId = 1L;

    // 基准值
    private BigDecimal baseTemp = new BigDecimal("25");
    private BigDecimal baseHumidity = new BigDecimal("60");
    private BigDecimal baseLight = new BigDecimal("500");
    private BigDecimal baseCo2 = new BigDecimal("400");
    private BigDecimal baseSoilMoisture = new BigDecimal("50");

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
        log.info("模拟网关{}", enabled ? "已启动" : "已停止");
    }

    public boolean isEnabled() {
        return enabled;
    }

    public void setMockPointId(Long pointId) {
        this.mockPointId = pointId;
        log.info("模拟检测点设置为: {}", pointId);
    }

    /**
     * 每5秒生成一条环境数据
     */
    @Scheduled(fixedRate = 30000)
    public void generateEnvironmentData() {
        if (!enabled) {
            return;
        }

        EnvironmentDataDTO dto = new EnvironmentDataDTO();
        dto.setPointId(mockPointId);
        dto.setRecordedAt(LocalDateTime.now());

        // 生成随机波动的数据
        dto.setTemperature(generateValue(baseTemp, 5, 10, 40));
        dto.setHumidity(generateValue(baseHumidity, 15, 20, 90));
        dto.setLight(generateValue(baseLight, 200, 0, 2000));
        dto.setCo2(generateValue(baseCo2, 150, 200, 1500));
        dto.setSoilMoisture(generateValue(baseSoilMoisture, 10, 10, 80));

        // 缓慢降低土壤湿度（模拟蒸发）
        baseSoilMoisture = baseSoilMoisture.subtract(new BigDecimal("0.5"));
        if (baseSoilMoisture.compareTo(new BigDecimal("30")) < 0) {
            baseSoilMoisture = new BigDecimal("70"); // 回升
        }

        sensorDataService.saveData(dto);
        log.debug("模拟数据: 温度={}℃, 湿度={}%, 光照={}lux, CO2={}ppm, 土壤湿度={}%",
                dto.getTemperature(), dto.getHumidity(), dto.getLight(), dto.getCo2(), dto.getSoilMoisture());
    }

    /**
     * 生成带随机波动的值
     */
    private BigDecimal generateValue(BigDecimal base, int fluctuation, double min, double max) {
        double delta = (random.nextDouble() - 0.5) * 2 * fluctuation;
        BigDecimal result = base.add(BigDecimal.valueOf(delta)).setScale(2, RoundingMode.HALF_UP);

        // 限制范围
        if (result.compareTo(BigDecimal.valueOf(min)) < 0) {
            result = BigDecimal.valueOf(min);
        }
        if (result.compareTo(BigDecimal.valueOf(max)) > 0) {
            result = BigDecimal.valueOf(max);
        }

        return result;
    }

    /**
     * 模拟一次灌溉（增加土壤湿度）
     */
    public void simulateIrrigation(BigDecimal waterAmount) {
        baseSoilMoisture = baseSoilMoisture.add(waterAmount.multiply(new BigDecimal("2")));
        if (baseSoilMoisture.compareTo(new BigDecimal("80")) > 0) {
            baseSoilMoisture = new BigDecimal("80");
        }
        log.info("模拟灌溉: 土壤湿度升至 {}%", baseSoilMoisture);
    }

    /**
     * 重置基准值
     */
    public void resetBaseValues() {
        baseTemp = new BigDecimal("25");
        baseHumidity = new BigDecimal("60");
        baseLight = new BigDecimal("500");
        baseCo2 = new BigDecimal("400");
        baseSoilMoisture = new BigDecimal("50");
        log.info("基准值已重置");
    }

    /**
     * 手动生成一条数据
     */
    public EnvironmentDataDTO generateOneData(Long pointId) {
        EnvironmentDataDTO dto = new EnvironmentDataDTO();
        dto.setPointId(pointId);
        dto.setRecordedAt(LocalDateTime.now());
        dto.setTemperature(generateValue(baseTemp, 5, 10, 40));
        dto.setHumidity(generateValue(baseHumidity, 15, 20, 90));
        dto.setLight(generateValue(baseLight, 200, 0, 2000));
        dto.setCo2(generateValue(baseCo2, 150, 200, 1500));
        dto.setSoilMoisture(generateValue(baseSoilMoisture, 10, 10, 80));

        return sensorDataService.saveData(dto);
    }
}
