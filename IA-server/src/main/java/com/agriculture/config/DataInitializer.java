package com.agriculture.config;

import com.agriculture.entity.User;
import com.agriculture.mapper.UserMapper;
import com.agriculture.model.dto.DeviceDTO;
import com.agriculture.model.dto.FarmDTO;
import com.agriculture.model.dto.MonitorPointDTO;
import com.agriculture.service.DeviceService;
import com.agriculture.service.FarmService;
import com.agriculture.service.MonitorPointService;
import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 数据初始化配置
 */
@Slf4j
@Configuration
@RequiredArgsConstructor
public class DataInitializer {

    private final UserMapper userMapper;
    private final FarmService farmService;
    private final MonitorPointService monitorPointService;
    private final DeviceService deviceService;

    @Bean
    @ConditionalOnProperty(name = "app.init-data", havingValue = "true", matchIfMissing = false)
    public CommandLineRunner initData() {
        return args -> {
            log.info("开始初始化测试数据...");

            Long userId = null;

            // 初始化默认用户
            LambdaQueryWrapper<User> userWrapper = new LambdaQueryWrapper<>();
            if (userMapper.selectCount(userWrapper) == 0) {
                User user = new User();
                user.setUsername("admin");
                user.setPasswordHash("$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH");
                user.setNickname("系统管理员");
                user.setPhone("13800000000");
                user.setRole("admin");
                user.setStatus(1);
                userMapper.insert(user);
                userId = user.getId();
                log.info("创建用户: {}", user.getUsername());
            } else {
                userId = userMapper.selectList(null).get(0).getId();
            }

            Long farmId = null;

            // 初始化农场
            if (farmService.getAllFarms().isEmpty()) {
                FarmDTO.CreateRequest farmRequest = new FarmDTO.CreateRequest();
                farmRequest.setUserId(userId);
                farmRequest.setFarmName("智慧农业示范农场");
                farmRequest.setFarmCode("FARM_001");
                farmRequest.setLocation("北京市海淀区");
                farmRequest.setProvince("北京");
                farmRequest.setCity("海淀区");
                FarmDTO farm = farmService.createFarm(farmRequest);
                farmId = farm.getId();
                log.info("创建农场: {}", farm.getFarmName());
            } else {
                farmId = farmService.getAllFarms().get(0).getId();
            }

            // 初始化检测点
            if (monitorPointService.getAllPoints().isEmpty()) {
                MonitorPointDTO.CreateRequest pointRequest = new MonitorPointDTO.CreateRequest();
                pointRequest.setFarmId(farmId);
                pointRequest.setPointCode("POINT_001");
                pointRequest.setPointName("1号大棚");
                pointRequest.setLocation("东区");
                monitorPointService.createPoint(pointRequest);
                log.info("创建检测点: 1号大棚");
            }

            // 初始化设备
            if (deviceService.getAllDevices().isEmpty()) {
                Long pointId = monitorPointService.getAllPoints().get(0).getId();
                
                // 水泵
                DeviceDTO.CreateRequest pumpRequest = new DeviceDTO.CreateRequest();
                pumpRequest.setPointId(pointId);
                pumpRequest.setDeviceCode("pump_001");
                pumpRequest.setDeviceName("水泵1号");
                pumpRequest.setDeviceType("pump");
                deviceService.createDevice(pumpRequest);

                // 水阀
                DeviceDTO.CreateRequest valveRequest = new DeviceDTO.CreateRequest();
                valveRequest.setPointId(pointId);
                valveRequest.setDeviceCode("valve_001");
                valveRequest.setDeviceName("水阀1号");
                valveRequest.setDeviceType("valve");
                deviceService.createDevice(valveRequest);

                // LED补光灯
                DeviceDTO.CreateRequest ledRequest = new DeviceDTO.CreateRequest();
                ledRequest.setPointId(pointId);
                ledRequest.setDeviceCode("led_001");
                ledRequest.setDeviceName("LED补光灯1号");
                ledRequest.setDeviceType("led");
                deviceService.createDevice(ledRequest);

                // 通风风扇
                DeviceDTO.CreateRequest fanRequest = new DeviceDTO.CreateRequest();
                fanRequest.setPointId(pointId);
                fanRequest.setDeviceCode("fan_001");
                fanRequest.setDeviceName("通风风扇1号");
                fanRequest.setDeviceType("fan");
                deviceService.createDevice(fanRequest);

                log.info("创建4个设备: 水泵、水阀、LED补光灯、通风风扇");
            }

            log.info("测试数据初始化完成");
        };
    }
}
