package com.agriculture.config;

import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.DeviceService;
import com.agriculture.service.MonitorPointService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 数据初始化配置
 */
@Slf4j
@Configuration
@RequiredArgsConstructor
public class DataInitializer {

    private final MonitorPointService monitorPointService;
    private final DeviceService deviceService;

    @Bean
    public CommandLineRunner initData() {
        return args -> {
            log.info("开始初始化测试数据...");

            // 初始化检测点
            if (monitorPointService.getAllPoints().isEmpty()) {
                MonitorPointDTO.CreateRequest pointRequest = new MonitorPointDTO.CreateRequest();
                pointRequest.setPointId("POINT_001");
                pointRequest.setPointName("1号大棚");
                pointRequest.setLocation("东区");
                pointRequest.setCropType("番茄");
                monitorPointService.createPoint(pointRequest);
                log.info("创建检测点: 1号大棚");
            }

            // 初始化设备
            if (deviceService.getAllDevices().isEmpty()) {
                // 水泵
                DeviceDTO.CreateRequest pumpRequest = new DeviceDTO.CreateRequest();
                pumpRequest.setPointId(1L);
                pumpRequest.setDeviceId("pump_001");
                pumpRequest.setDeviceName("水泵1号");
                pumpRequest.setDeviceType("pump");
                deviceService.createDevice(pumpRequest);

                // 水阀
                DeviceDTO.CreateRequest valveRequest = new DeviceDTO.CreateRequest();
                valveRequest.setPointId(1L);
                valveRequest.setDeviceId("valve_001");
                valveRequest.setDeviceName("水阀1号");
                valveRequest.setDeviceType("valve");
                deviceService.createDevice(valveRequest);

                // LED补光灯
                DeviceDTO.CreateRequest ledRequest = new DeviceDTO.CreateRequest();
                ledRequest.setPointId(1L);
                ledRequest.setDeviceId("led_001");
                ledRequest.setDeviceName("LED补光灯1号");
                ledRequest.setDeviceType("led");
                deviceService.createDevice(ledRequest);

                // 通风风扇
                DeviceDTO.CreateRequest fanRequest = new DeviceDTO.CreateRequest();
                fanRequest.setPointId(1L);
                fanRequest.setDeviceId("fan_001");
                fanRequest.setDeviceName("通风风扇1号");
                fanRequest.setDeviceType("fan");
                deviceService.createDevice(fanRequest);

                log.info("创建4个设备: 水泵、水阀、LED补光灯、通风风扇");
            }

            log.info("测试数据初始化完成");
        };
    }
}
