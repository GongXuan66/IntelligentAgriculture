-- ============================================================
-- 智慧农业控制系统测试数据
-- 版本: 3.0 (优化版 - 14张表)
-- 更新日期: 2026-03-22
-- 说明: 包含多用户、多农场、完整业务流程的测试数据
-- ============================================================

USE agriculture;

-- 清空现有数据（按外键依赖顺序）
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE ai_interaction;
TRUNCATE TABLE irrigation_threshold_config;
TRUNCATE TABLE crop_planting;
TRUNCATE TABLE crop_stage_config;
TRUNCATE TABLE crop_type;
TRUNCATE TABLE alarm;
TRUNCATE TABLE irrigation_log;
TRUNCATE TABLE sensor_data;
TRUNCATE TABLE device;
TRUNCATE TABLE monitor_point;
TRUNCATE TABLE farm;
TRUNCATE TABLE user;
SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================
-- 一、用户数据
-- ============================================================

INSERT INTO user (id, username, password_hash, nickname, phone, email, role, status) VALUES
(1, 'admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '系统管理员', '13800000000', 'admin@agri.com', 'admin', 1),
(2, 'farmer001', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '张农户', '13800000001', 'zhang@agri.com', 'farmer', 1),
(3, 'farmer002', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '李农户', '13800000002', 'li@agri.com', 'farmer', 1),
(4, 'farmer003', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '王农户', '13800000003', 'wang@agri.com', 'farmer', 1);

-- ============================================================
-- 二、农场数据
-- ============================================================

INSERT INTO farm (id, user_id, farm_name, farm_code, location, province, city, area, description, status) VALUES
(1, 2, '张氏果蔬种植基地', 'FARM001', '江苏省南京市江宁区', '江苏', '南京', 50.00, '主营番茄、黄瓜等蔬菜种植', 1),
(2, 3, '李家生态农场', 'FARM002', '江苏省苏州市吴中区', '江苏', '苏州', 80.00, '有机蔬菜和水果种植', 1),
(3, 4, '王家水稻合作社', 'FARM003', '江苏省盐城市建湖县', '江苏', '盐城', 200.00, '水稻规模化种植', 1);

-- ============================================================
-- 三、检测点/地块数据
-- ============================================================

INSERT INTO monitor_point (id, farm_id, point_code, point_name, location, area, soil_type, status) VALUES
-- 张农户的农场
(1, 1, 'POINT001', '1号番茄大棚', '东侧A区', 2.00, 'loam', 1),
(2, 1, 'POINT002', '2号黄瓜大棚', '东侧B区', 1.50, 'loam', 1),
(3, 1, 'POINT003', '3号育苗温室', '西侧A区', 1.00, 'loam', 1),
-- 李农户的农场
(4, 2, 'POINT004', '草莓种植区', '南区1号', 3.00, 'sandy', 1),
(5, 2, 'POINT005', '西瓜种植区', '南区2号', 5.00, 'sandy', 1),
-- 王农户的农场
(6, 3, 'POINT006', '水稻1号田', '北区', 50.00, 'clay', 1),
(7, 3, 'POINT007', '水稻2号田', '南区', 60.00, 'clay', 1);

-- ============================================================
-- 四、设备数据
-- ============================================================

INSERT INTO device (id, point_id, device_code, device_name, device_type, device_model, manufacturer, status, last_heartbeat, installed_at) VALUES
-- 1号点设备
(1, 1, 'DEV001', '主控水泵', 'pump', 'PUMP-100', '智农科技', 1, NOW(), '2026-01-01'),
(2, 1, 'DEV002', '电磁阀A', 'valve', 'VALVE-50', '智农科技', 1, NOW(), '2026-01-01'),
(3, 1, 'DEV003', 'LED补光灯', 'led', 'LED-200W', '智农科技', 1, NOW(), '2026-01-01'),
(4, 1, 'DEV004', '环境传感器', 'sensor', 'SENSOR-PRO', '智农科技', 1, NOW(), '2026-01-01'),
(5, 1, 'DEV005', '通风风扇', 'fan', 'FAN-400', '智农科技', 1, NOW(), '2026-01-01'),
-- 2号点设备
(6, 2, 'DEV006', '主控水泵', 'pump', 'PUMP-100', '智农科技', 1, NOW(), '2026-01-01'),
(7, 2, 'DEV007', '电磁阀B', 'valve', 'VALVE-50', '智农科技', 1, NOW(), '2026-01-01'),
(8, 2, 'DEV008', '环境传感器', 'sensor', 'SENSOR-PRO', '智农科技', 1, NOW(), '2026-01-01'),
-- 其他检测点设备
(9, 3, 'DEV009', '育苗区水泵', 'pump', 'PUMP-50', '智农科技', 1, NOW(), '2026-01-01'),
(10, 3, 'DEV010', '环境传感器', 'sensor', 'SENSOR-PRO', '智农科技', 1, NOW(), '2026-01-01'),
(11, 4, 'DEV011', '草莓区水泵', 'pump', 'PUMP-100', '智农科技', 1, NOW(), '2026-02-01'),
(12, 4, 'DEV012', '环境传感器', 'sensor', 'SENSOR-PRO', '智农科技', 1, NOW(), '2026-02-01'),
(13, 6, 'DEV013', '水稻田灌溉泵', 'pump', 'PUMP-200', '智农科技', 1, NOW(), '2026-03-01'),
(14, 6, 'DEV014', '水位传感器', 'sensor', 'WATER-LEVEL', '智农科技', 1, NOW(), '2026-03-01');

-- ============================================================
-- 五、传感器数据（过去24小时）
-- ============================================================

DELIMITER //
CREATE PROCEDURE generate_sensor_data()
BEGIN
    DECLARE i INT DEFAULT 0;
    DECLARE hours_ago INT;
    DECLARE base_temp DECIMAL(5,2);
    DECLARE base_humidity DECIMAL(5,2);
    DECLARE base_soil DECIMAL(5,2);
    DECLARE base_light DECIMAL(10,2);
    DECLARE recorded_time DATETIME;
    
    -- 为每个检测点生成24小时数据
    WHILE i < 24 DO
        SET hours_ago = 23 - i;
        SET recorded_time = DATE_SUB(NOW(), INTERVAL hours_ago HOUR);
        
        -- 1号点：番茄大棚（结果期，土壤湿度适中）
        SET base_soil = 55 + (RAND() - 0.5) * 10;
        INSERT INTO sensor_data (point_id, temperature, humidity, light, co2, soil_moisture, soil_temperature, soil_ph, recorded_at) VALUES
        (1, 
         25 + (RAND() - 0.5) * 8,
         60 + (RAND() - 0.5) * 20,
         CASE WHEN hours_ago BETWEEN 6 AND 18 THEN 25000 + RAND() * 15000 ELSE RAND() * 100 END,
         400 + RAND() * 200,
         base_soil,
         22 + RAND() * 3,
         6.5 + RAND() * 0.5,
         recorded_time);
        
        -- 2号点：黄瓜大棚
        SET base_soil = 62 + (RAND() - 0.5) * 10;
        INSERT INTO sensor_data (point_id, temperature, humidity, light, co2, soil_moisture, soil_temperature, soil_ph, recorded_at) VALUES
        (2,
         26 + (RAND() - 0.5) * 8,
         65 + (RAND() - 0.5) * 20,
         CASE WHEN hours_ago BETWEEN 6 AND 18 THEN 28000 + RAND() * 12000 ELSE RAND() * 100 END,
         420 + RAND() * 180,
         base_soil,
         23 + RAND() * 3,
         6.3 + RAND() * 0.5,
         recorded_time);
        
        -- 3号点：育苗温室（湿度较高）
        SET base_soil = 65 + (RAND() - 0.5) * 8;
        INSERT INTO sensor_data (point_id, temperature, humidity, light, co2, soil_moisture, soil_temperature, soil_ph, recorded_at) VALUES
        (3,
         24 + (RAND() - 0.5) * 5,
         70 + (RAND() - 0.5) * 15,
         CASE WHEN hours_ago BETWEEN 6 AND 18 THEN 20000 + RAND() * 10000 ELSE RAND() * 50 END,
         380 + RAND() * 150,
         base_soil,
         21 + RAND() * 2,
         6.8 + RAND() * 0.3,
         recorded_time);
        
        -- 4号点：草莓区
        SET base_soil = 58 + (RAND() - 0.5) * 12;
        INSERT INTO sensor_data (point_id, temperature, humidity, light, co2, soil_moisture, soil_temperature, soil_ph, recorded_at) VALUES
        (4,
         22 + (RAND() - 0.5) * 6,
         65 + (RAND() - 0.5) * 15,
         CASE WHEN hours_ago BETWEEN 6 AND 18 THEN 22000 + RAND() * 8000 ELSE RAND() * 50 END,
         390 + RAND() * 160,
         base_soil,
         20 + RAND() * 3,
         5.8 + RAND() * 0.5,
         recorded_time);
        
        -- 6号点：水稻田（水田，湿度极高）
        INSERT INTO sensor_data (point_id, temperature, humidity, light, co2, soil_moisture, soil_temperature, soil_ph, recorded_at) VALUES
        (6,
         23 + (RAND() - 0.5) * 8,
         85 + (RAND() - 0.5) * 10,
         CASE WHEN hours_ago BETWEEN 6 AND 18 THEN 30000 + RAND() * 20000 ELSE RAND() * 100 END,
         350 + RAND() * 100,
         88 + RAND() * 5,
         22 + RAND() * 4,
         6.0 + RAND() * 0.5,
         recorded_time);
        
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

CALL generate_sensor_data();
DROP PROCEDURE generate_sensor_data;

-- ============================================================
-- 六、作物类型配置
-- ============================================================

INSERT INTO crop_type (crop_code, crop_name, category, growth_cycle_days, water_requirement, temperature_range, description, is_active, sort_order) VALUES
('tomato', '番茄', 'vegetable', 120, 'medium', '20-28℃', '喜温作物，需水量中等', 1, 1),
('cucumber', '黄瓜', 'vegetable', 90, 'high', '22-30℃', '喜温喜湿，需水量大', 1, 2),
('strawberry', '草莓', 'fruit', 180, 'medium', '15-25℃', '喜凉作物，果实期控水提糖', 1, 3),
('watermelon', '西瓜', 'fruit', 100, 'medium', '25-35℃', '耐热耐旱，需水量中等', 1, 4),
('rice', '水稻', 'grain', 140, 'high', '22-32℃', '水生作物，全生长期需水层', 1, 5);

-- ============================================================
-- 七、作物种植数据
-- ============================================================

INSERT INTO crop_planting (point_id, crop_code, crop_name, variety, planting_date, expected_harvest_date, current_stage, status) VALUES
(1, 'tomato', '番茄', '金棚1号', '2026-01-15', '2026-05-15', 'fruiting', 1),
(2, 'cucumber', '黄瓜', '津春4号', '2026-02-01', '2026-05-01', 'fruiting', 1),
(3, 'tomato', '番茄', '金棚1号', '2026-03-01', '2026-07-01', 'seedling', 1),
(4, 'strawberry', '草莓', '红颜', '2025-10-01', '2026-05-01', 'fruiting', 1),
(6, 'rice', '水稻', '南粳46', '2026-03-01', '2026-07-15', 'sowing', 1);

-- ============================================================
-- 八、作物生长阶段配置
-- ============================================================

INSERT INTO crop_stage_config (crop_code, stage_code, stage_name, stage_order, start_day, end_day, min_humidity, max_humidity, optimal_humidity, irrigation_factor, frequency_hint, water_needs) VALUES
-- 番茄
('tomato', 'seedling', '幼苗期', 1, 1, 30, 60, 75, 68, 0.80, '每2-3天少量浇水', '需水量较少'),
('tomato', 'growing', '生长期', 2, 31, 70, 55, 70, 62, 1.00, '每2天浇水一次', '营养生长旺盛'),
('tomato', 'flowering', '开花期', 3, 71, 90, 55, 65, 60, 1.10, '保持土壤湿润', '开花结果关键期'),
('tomato', 'fruiting', '结果期', 4, 91, 120, 50, 65, 58, 1.20, '每1-2天浇水', '果实膨大需水量大'),
-- 黄瓜
('cucumber', 'seedling', '幼苗期', 1, 1, 25, 65, 80, 72, 0.85, '适度控水促根', '幼苗期适度控水'),
('cucumber', 'growing', '伸蔓期', 2, 26, 55, 60, 75, 68, 1.00, '每2天浇水', '蔓叶生长旺盛'),
('cucumber', 'flowering', '开花期', 3, 56, 70, 60, 70, 65, 1.10, '保持土壤湿润', '开花坐果期'),
('cucumber', 'fruiting', '结果期', 4, 71, 90, 60, 75, 68, 1.20, '每天或隔天浇水', '采收期需水充足'),
-- 草莓
('strawberry', 'seedling', '育苗期', 1, 1, 45, 60, 70, 65, 0.90, '保持湿润', '培育壮苗'),
('strawberry', 'growing', '生长期', 2, 46, 105, 55, 65, 60, 1.00, '每2-3天浇水', '营养生长'),
('strawberry', 'flowering', '开花期', 3, 106, 135, 50, 60, 55, 1.05, '适度控水', '花期管理'),
('strawberry', 'fruiting', '结果期', 4, 136, 180, 50, 60, 55, 0.80, '控水提糖', '收获期适度控水'),
-- 水稻
('rice', 'sowing', '播种期', 1, 1, 15, 85, 95, 90, 0.60, '浅水层3-5cm', '保持浅水'),
('rice', 'seedling', '秧苗期', 2, 16, 45, 80, 90, 85, 0.80, '保持水层', '保持水层'),
('rice', 'tillering', '分蘖期', 3, 46, 80, 75, 90, 82, 1.00, '适度晒田', '适度晒田促分蘖'),
('rice', 'booting', '孕穗期', 4, 81, 105, 80, 95, 88, 1.20, '深水护胎', '需水关键期'),
('rice', 'heading', '抽穗期', 5, 106, 120, 80, 90, 85, 1.10, '保持水层', '保持水层'),
('rice', 'maturity', '成熟期', 6, 121, 140, 70, 85, 78, 0.70, '排水晒田', '排水促成熟');

-- ============================================================
-- 九、灌溉记录数据（含决策信息）
-- ============================================================

INSERT INTO irrigation_log (point_id, water_amount, duration, mode, decision_type, current_moisture, predicted_moisture, crop_stage, irrigation_factor, confidence, soil_moisture_before, soil_moisture_after, temperature, humidity, trigger_reason, start_time, end_time) VALUES
-- 1号点灌溉记录
(1, 8.50, 17, 0, 'predictive', 48.00, 35.00, 'fruiting', 1.20, 0.82, 48.00, 56.00, 28.00, 45.00, '预测2小时后湿度将降至35%，提前灌溉', '2026-03-21 06:30:00', '2026-03-21 06:47:00'),
(1, 6.00, 12, 0, 'adaptive', 52.00, NULL, 'fruiting', 1.20, 0.75, 52.00, 58.00, 32.00, 40.00, '高温天气，湿度下降快', '2026-03-21 14:00:00', '2026-03-21 14:12:00'),
-- 2号点灌溉记录
(2, 10.00, 20, 0, 'stage_based', 55.00, NULL, 'fruiting', 1.20, 0.88, 55.00, 65.00, 27.00, 50.00, '结果期，保证水分供应', '2026-03-21 07:00:00', '2026-03-21 07:20:00'),
-- 3号点灌溉记录
(3, 3.00, 6, 0, 'adaptive', 60.00, NULL, 'seedling', 0.80, 0.70, 60.00, 66.00, 24.00, 65.00, '幼苗期适度补水', '2026-03-21 08:00:00', '2026-03-21 08:06:00'),
-- 4号点灌溉记录
(4, 7.50, 15, 0, 'predictive', 50.00, 42.00, 'fruiting', 0.80, 0.80, 50.00, 58.00, 25.00, 55.00, '预测下午蒸发量大', '2026-03-21 10:00:00', '2026-03-21 10:15:00'),
-- 手动灌溉记录
(1, 5.00, 10, 1, 'manual', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 26.00, 60.00, '农户手动灌溉', '2026-03-20 18:00:00', '2026-03-20 18:10:00');

-- ============================================================
-- 十、灌溉阈值配置
-- ============================================================

INSERT INTO irrigation_threshold_config (point_id, moisture_threshold, max_single_irrigation, min_irrigation_interval, enable_predictive, enable_auto_control, prediction_mode, learned_moisture_gain, learning_sample_count, learning_confidence) VALUES
(1, 40, 180, 30, 1, 1, 'ewma', 1.45, 5, 0.55),
(2, 35, 200, 25, 1, 1, 'ewma', 1.55, 3, 0.45),
(3, 45, 120, 60, 1, 1, 'ewma', 1.50, 2, 0.40),
(4, 40, 180, 30, 1, 1, 'ewma', 1.40, 4, 0.50),
(6, 70, 300, 120, 1, 1, 'ewma', 1.20, 1, 0.30);

-- ============================================================
-- 十一、报警记录
-- ============================================================

INSERT INTO alarm (point_id, alarm_type, alarm_level, alarm_value, threshold, message, status, handled_by, handled_at, handle_note, created_at) VALUES
(1, 'HIGH_TEMPERATURE', 2, 38.50, 35.00, '温度过高，已超过35℃阈值', 1, 2, '2026-03-21 15:00:00', '已开启通风设备', '2026-03-21 14:30:00'),
(1, 'LOW_SOIL_MOISTURE', 3, 32.00, 40.00, '土壤湿度过低，已低于40%阈值', 1, 2, '2026-03-21 14:15:00', '已启动灌溉', '2026-03-21 14:00:00'),
(2, 'HIGH_HUMIDITY', 1, 88.00, 85.00, '空气湿度过高，可能影响黄瓜生长', 1, 3, '2026-03-20 10:00:00', '已开启通风', '2026-03-20 09:30:00'),
(4, 'LOW_LIGHT', 1, 5000.00, 10000.00, '光照不足，建议补光', 0, NULL, NULL, NULL, '2026-03-21 07:00:00');

-- ============================================================
-- 十二、AI交互记录（合并对话、推荐、报告）
-- ============================================================

-- 对话记录 (interaction_type = 'chat')
INSERT INTO ai_interaction (user_id, point_id, interaction_type, session_id, role, title, content, token_count, model, created_at) VALUES
-- 张农户的AI对话
(2, 1, 'chat', 'session_001', 'user', NULL, '我的番茄大棚最近叶子发黄是什么原因？', 15, 'qwen', '2026-03-21 09:00:00'),
(2, 1, 'chat', 'session_001', 'assistant', NULL, '番茄叶子发黄可能有以下几种原因：

1. **缺氮**：老叶先发黄，逐渐向新叶发展
2. **缺镁**：叶脉间失绿，叶脉仍保持绿色
3. **缺铁**：新叶发黄，老叶正常
4. **水分问题**：过干或过湿都会导致黄叶
5. **病害**：如根腐病、枯萎病等

根据您大棚的传感器数据，土壤湿度目前为48%，属于适中范围。建议您：
- 检查叶片黄化的具体位置（老叶还是新叶）
- 追施适量的氮肥
- 观察根系是否有腐烂现象', 180, 'qwen', '2026-03-21 09:00:05'),
(2, 1, 'chat', 'session_001', 'user', NULL, '是老叶先发黄的，我应该怎么做？', 12, 'qwen', '2026-03-21 09:01:00'),
(2, 1, 'chat', 'session_001', 'assistant', NULL, '根据您的描述，老叶先发黄很可能是**缺氮**引起的。建议采取以下措施：

1. **追施氮肥**：每亩施尿素10-15公斤
2. **叶面喷施**：用0.5%尿素溶液进行叶面喷施，见效更快
3. **配合浇水**：施肥后适当浇水，促进吸收

系统已为您记录此次咨询，后续会持续关注您大棚的作物状态。', 120, 'qwen', '2026-03-21 09:01:08'),
-- 李农户的AI对话
(3, 4, 'chat', 'session_002', 'user', NULL, '草莓快要收获了，需要注意什么？', 12, 'qwen', '2026-03-21 10:00:00'),
(3, 4, 'chat', 'session_002', 'assistant', NULL, '草莓收获期的管理要点：

**水分管理：**
- 适当控水，提高果实糖度
- 保持土壤湿度在50-60%
- 避免大水漫灌，防止烂果

**温度管理：**
- 白天保持20-25℃
- 夜间保持8-12℃
- 温差大有利于糖分积累

**采摘建议：**
- 果实全红时采摘
- 上午露水干后采摘最佳
- 轻拿轻放，保留果柄

根据您的传感器数据，目前土壤湿度58%，温度22℃，非常适合草莓成熟。建议未来3-5天适当减少灌溉。', 200, 'qwen', '2026-03-21 10:00:10'),
(3, 4, 'chat', 'session_002', 'user', NULL, '好的，系统可以自动帮我控制灌溉吗？', 15, 'qwen', '2026-03-21 10:01:00'),
(3, 4, 'chat', 'session_002', 'assistant', NULL, '可以的！系统已经为您的草莓种植区（4号地块）启用了智能灌溉功能。

当前配置：
- 湿度阈值：40%
- 预测灌溉：已开启
- 作物阶段：收获期（灌溉系数0.80）

系统会自动：
1. 监测土壤湿度变化
2. 预测未来湿度趋势
3. 在合适的时机自动灌溉
4. 根据收获期特性减少用水量

您可以随时在APP中查看灌溉记录和调整设置。', 180, 'qwen', '2026-03-21 10:01:12');

-- AI推荐 (interaction_type = 'recommendation')
INSERT INTO ai_interaction (user_id, point_id, interaction_type, title, content, confidence, created_at) VALUES
(2, 1, 'recommendation', '灌溉建议', '根据天气预报，明天将有高温，建议今天傍晚进行预防性灌溉，避免明天中午土壤过干。', 0.85, '2026-03-21 18:00:00'),
(2, 1, 'recommendation', '病虫害预警', '当前温度湿度条件下，番茄晚疫病发生风险较高，建议提前喷施保护性杀菌剂。', 0.78, '2026-03-21 18:00:00'),
(3, 4, 'recommendation', '采摘提醒', '您的草莓即将进入最佳采摘期，建议未来3天内完成主要采摘工作。', 0.92, '2026-03-21 08:00:00'),
(4, 6, 'recommendation', '水田管理', '水稻播种期需保持浅水层（3-5cm），请确保灌溉系统正常运行。', 0.88, '2026-03-20 10:00:00');

-- AI分析报告 (interaction_type = 'report')
INSERT INTO ai_interaction (user_id, interaction_type, title, content, report_type, report_date, created_at) VALUES
(2, 'report', '张氏果蔬种植基地日报', 
'{"summary":"今日基地运行正常，共完成3次自动灌溉，节水效果明显。","data":{"irrigationCount":3,"totalWater":19.5,"avgMoisture":54.2,"alerts":2},"insights":["智能灌溉系统较传统方式节水约22%","番茄大棚湿度控制良好","温度波动在正常范围内"],"suggestions":["建议关注明日高温天气","番茄可适当追施氮肥","继续观察黄叶改善情况"]}',
'daily', '2026-03-21', '2026-03-21 20:00:00'),
(3, 'report', '李家生态农场周报',
'{"summary":"本周农场整体运行良好，草莓进入收获期，西瓜长势正常。","data":{"points":2,"irrigationCount":12,"totalWater":85.3,"avgTemp":23.5},"insights":["草莓品质优良，糖度预计可达12%以上","西瓜生长处于伸蔓期，需要适量追肥","本周无重大设备故障"],"suggestions":["草莓本周完成采摘","西瓜区追施磷钾肥","检查灌溉设备运行状态"]}',
'weekly', '2026-03-21', '2026-03-21 20:00:00');

-- ============================================================
-- 十三、场景模拟数据
-- ============================================================

-- 场景1：高温天气模拟（连续高温数据）
INSERT INTO sensor_data (point_id, temperature, humidity, light, soil_moisture, recorded_at) VALUES
(1, 38.00, 35.00, 45000.00, 42.00, DATE_SUB(NOW(), INTERVAL 2 HOUR)),
(1, 39.50, 32.00, 48000.00, 40.00, DATE_SUB(NOW(), INTERVAL 1 HOUR)),
(1, 40.00, 30.00, 50000.00, 38.00, NOW());

-- 场景2：雨后高湿模拟
INSERT INTO sensor_data (point_id, temperature, humidity, light, soil_moisture, recorded_at) VALUES
(2, 22.00, 92.00, 8000.00, 78.00, DATE_SUB(NOW(), INTERVAL 3 HOUR)),
(2, 23.00, 88.00, 15000.00, 75.00, DATE_SUB(NOW(), INTERVAL 2 HOUR)),
(2, 24.00, 85.00, 20000.00, 72.00, DATE_SUB(NOW(), INTERVAL 1 HOUR));

-- ============================================================
-- 数据插入完成
-- ============================================================
SELECT '测试数据初始化完成！' AS message;
SELECT COUNT(*) AS user_count FROM user;
SELECT COUNT(*) AS farm_count FROM farm;
SELECT COUNT(*) AS point_count FROM monitor_point;
SELECT COUNT(*) AS device_count FROM device;
SELECT COUNT(*) AS sensor_count FROM sensor_data;
SELECT COUNT(*) AS irrigation_count FROM irrigation_log;
SELECT COUNT(*) AS ai_count FROM ai_interaction;