package com.agriculture.config;

import com.agriculture.entity.Alarm;
import com.agriculture.entity.IrrigationLog;
import com.agriculture.entity.SensorData;
import com.agriculture.mapper.AlarmMapper;
import com.agriculture.mapper.IrrigationLogMapper;
import com.agriculture.mapper.SensorDataMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Profile;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Random;

/**
 * 测试数据生成器
 * 仅在 test-data profile 激活时运行
 * 
 * 使用方式: 启动时添加参数 --spring.profiles.active=test-data
 */
@Slf4j
@Configuration
@RequiredArgsConstructor
public class TestDataGenerator {

    private final SensorDataMapper sensorDataMapper;
    private final IrrigationLogMapper irrigationLogMapper;
    private final AlarmMapper alarmMapper;
    private final Random random = new Random();

    @Bean
    @Profile("test-data")
    public CommandLineRunner generateTestData() {
        return args -> {
            log.info("========== 开始生成测试数据 ==========");
            
            Long pointId = 1L;
            
            // 生成环境历史数据（过去7天，每小时一条）
            generateSensorData(pointId);
            
            // 生成灌溉记录
            generateIrrigationLogs(pointId);
            
            // 生成报警记录
            generateAlarms(pointId);
            
            log.info("========== 测试数据生成完成 ==========");
        };
    }

    private void generateSensorData(Long pointId) {
        log.info("生成环境历史数据...");
        
        int count = 0;
        // 过去7天
        for (int day = 7; day >= 0; day--) {
            // 每天24小时
            for (int hour = 0; hour < 24; hour++) {
                LocalDateTime recordTime = LocalDateTime.now()
                        .minusDays(day)
                        .withHour(hour)
                        .withMinute(0)
                        .withSecond(0)
                        .withNano(0);
                
                SensorData data = new SensorData();
                data.setPointId(pointId);
                data.setTemperature(randomBigDecimal(20, 35));  // 20-35°C
                data.setHumidity(randomBigDecimal(40, 80));      // 40-80%
                data.setCo2(randomBigDecimal(400, 1000));        // 400-1000 ppm
                data.setSoilMoisture(randomBigDecimal(30, 70));  // 30-70%
                
                // 光照：白天高，夜晚低
                double lightBase = (hour >= 6 && hour <= 18) ? 5000 + random.nextDouble() * 45000 : 100 + random.nextDouble() * 500;
                data.setLight(BigDecimal.valueOf(Math.round(lightBase * 100) / 100.0));
                
                data.setRecordedAt(recordTime);
                data.setCreatedAt(recordTime);
                
                sensorDataMapper.insert(data);
                count++;
            }
        }
        log.info("环境数据生成完成: {} 条", count);
    }

    private void generateIrrigationLogs(Long pointId) {
        log.info("生成灌溉记录...");
        
        // 灌溉记录数据：[天数偏移, 开始小时, 水量(L), 持续时间(秒), 模式(0自动/1手动)]
        Object[][] logs = {
                {0, 6, 15.5, 62, 0},    // 今天早上自动灌溉
                {0, 15, 22.0, 88, 1},   // 今天下午手动灌溉
                {1, 7, 18.0, 72, 0},    // 昨天
                {1, 14, 20.5, 82, 0},
                {1, 18, 12.0, 48, 1},
                {2, 6, 25.0, 100, 0},   // 2天前
                {2, 15, 15.0, 60, 0},
                {3, 8, 30.0, 120, 0},   // 3天前
                {3, 16, 10.0, 40, 1},
                {4, 7, 20.0, 80, 0},    // 4天前
                {4, 14, 18.5, 74, 0},
                {5, 6, 22.5, 90, 0},    // 5天前
                {5, 17, 16.0, 64, 1},
                {6, 8, 28.0, 112, 0},   // 6天前
                {6, 16, 14.0, 56, 0},
        };
        
        int count = 0;
        for (Object[] logData : logs) {
            int dayOffset = (int) logData[0];
            int startHour = (int) logData[1];
            double waterAmount = (double) logData[2];
            int duration = (int) logData[3];
            int mode = (int) logData[4];
            
            LocalDateTime startTime = LocalDateTime.now()
                    .minusDays(dayOffset)
                    .withHour(startHour)
                    .withMinute(0)
                    .withSecond(0)
                    .withNano(0);
            LocalDateTime endTime = startTime.plusSeconds(duration);
            
            IrrigationLog irrigationLog = new IrrigationLog();
            irrigationLog.setPointId(pointId);
            irrigationLog.setWaterAmount(BigDecimal.valueOf(waterAmount));
            irrigationLog.setDuration(duration);
            irrigationLog.setMode(mode);
            irrigationLog.setStartTime(startTime);
            irrigationLog.setEndTime(endTime);
            irrigationLog.setCreatedAt(startTime);
            
            irrigationLogMapper.insert(irrigationLog);
            count++;
        }
        log.info("灌溉记录生成完成: {} 条", count);
    }

    private void generateAlarms(Long pointId) {
        log.info("生成报警记录...");
        
        // 报警数据：[类型, 报警值, 阈值, 天数偏移, 小时, 是否已处理]
        Object[][] alarms = {
                {"TEMPERATURE_HIGH", 38.5, 35.0, 5, 14, true},
                {"TEMPERATURE_HIGH", 36.2, 35.0, 3, 13, true},
                {"TEMPERATURE_HIGH", 37.8, 35.0, 0, 12, false},  // 未处理
                {"TEMPERATURE_LOW", 12.5, 15.0, 6, 5, true},
                {"HUMIDITY_LOW", 28.0, 35.0, 4, 11, true},
                {"HUMIDITY_LOW", 32.5, 35.0, 0, 10, false},      // 未处理
                {"SOIL_MOISTURE_LOW", 25.0, 30.0, 2, 10, true},
                {"SOIL_MOISTURE_LOW", 22.0, 30.0, 1, 9, true},
                {"CO2_HIGH", 1850.0, 1500.0, 3, 16, true},
                {"CO2_HIGH", 1620.0, 1500.0, 0, 8, false},       // 未处理
                {"LIGHT_LOW", 80.0, 200.0, 5, 6, true},
        };
        
        int count = 0;
        for (Object[] alarmData : alarms) {
            String type = (String) alarmData[0];
            double value = (double) alarmData[1];
            double threshold = (double) alarmData[2];
            int dayOffset = (int) alarmData[3];
            int hour = (int) alarmData[4];
            boolean handled = (boolean) alarmData[5];
            
            LocalDateTime createdTime = LocalDateTime.now()
                    .minusDays(dayOffset)
                    .withHour(hour)
                    .withMinute(0)
                    .withSecond(0)
                    .withNano(0);
            
            Alarm alarm = new Alarm();
            alarm.setPointId(pointId);
            alarm.setAlarmType(type);
            alarm.setAlarmValue(BigDecimal.valueOf(value));
            alarm.setThreshold(BigDecimal.valueOf(threshold));
            alarm.setStatus(handled ? 1 : 0);
            alarm.setCreatedAt(createdTime);
            if (handled) {
                alarm.setHandledAt(createdTime.plusHours(1));
            }
            
            alarmMapper.insert(alarm);
            count++;
        }
        log.info("报警记录生成完成: {} 条", count);
    }

    private BigDecimal randomBigDecimal(double min, double max) {
        double value = min + random.nextDouble() * (max - min);
        return BigDecimal.valueOf(Math.round(value * 100) / 100.0);
    }
}
