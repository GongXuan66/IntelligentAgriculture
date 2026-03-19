-- 测试数据生成脚本
-- 使用方法: 在MySQL中执行此脚本

USE agriculture;

-- =====================
-- 0. 清理旧数据（按正确顺序删除）
-- =====================
DELETE FROM alarm WHERE 1=1;
DELETE FROM irrigation_log WHERE 1=1;
DELETE FROM sensor_data WHERE 1=1;
DELETE FROM device WHERE 1=1;
DELETE FROM monitor_point WHERE 1=1;
DELETE FROM field WHERE 1=1;

-- =====================
-- 1. 地块数据 (field)
-- =====================
INSERT INTO field (id, field_id, field_name, field_type, location, area, crop_type, description, status) VALUES
(1, 'F001', '东区稻田', 'outdoor', '农场东侧', 8.5, '水稻', '主要水稻种植区，使用自动灌溉系统', 1),
(2, 'F002', '1号温室大棚', 'greenhouse', '农场中心区', 2.0, '番茄', '智能温室，种植优质番茄', 1),
(3, 'F003', '西果园', 'orchard', '农场西侧', 15.0, '苹果', '苹果果园，配备智能监测', 1),
(4, 'F004', '2号温室大棚', 'greenhouse', '农场中心区', 2.5, '黄瓜', '新建温室，种植有机黄瓜', 1),
(5, 'F005', '南区菜地', 'outdoor', '农场南侧', 5.0, '白菜', '露天蔬菜种植区', 1);

-- =====================
-- 2. 检测点数据 (monitor_point)
-- =====================
INSERT INTO monitor_point (id, field_id, point_id, point_name, location, crop_type, status) VALUES
-- 东区稻田
(1, 1, 'P001-A', 'A区', '东区北侧', '水稻', 1),
(2, 1, 'P001-B', 'B区', '东区南侧', '水稻', 1),
-- 1号温室大棚
(3, 2, 'P002-A', 'A区', '大棚东侧', '番茄', 1),
(4, 2, 'P002-B', 'B区', '大棚西侧', '番茄', 1),
-- 西果园
(5, 3, 'P003-A', 'A区', '果园北侧', '苹果', 1),
(6, 3, 'P003-B', 'B区', '果园南侧', '苹果', 1),
-- 2号温室大棚
(7, 4, 'P004-A', 'A区', '大棚北侧', '黄瓜', 1),
(8, 4, 'P004-B', 'B区', '大棚南侧', '黄瓜', 1),
-- 南区菜地
(9, 5, 'P005-A', 'A区', '菜地东侧', '白菜', 1),
(10, 5, 'P005-B', 'B区', '菜地西侧', '白菜', 1);

-- =====================
-- 3. 设备数据 (device)
-- =====================
INSERT INTO device (id, point_id, device_id, device_name, device_type, status) VALUES
-- 东区稻田 A区
(1, 1, 'D001-PUMP', '灌溉水泵1', 'pump', 1),
(2, 1, 'D001-VALVE', '电磁阀1', 'valve', 1),
-- 东区稻田 B区
(3, 2, 'D002-PUMP', '灌溉水泵2', 'pump', 1),
(4, 2, 'D002-VALVE', '电磁阀2', 'valve', 0),
-- 1号温室大棚 A区
(5, 3, 'D003-PUMP', '灌溉水泵', 'pump', 2),
(6, 3, 'D003-LED', '补光灯组', 'led', 2),
(7, 3, 'D003-FAN', '通风风扇', 'fan', 1),
-- 1号温室大棚 B区
(8, 4, 'D004-PUMP', '灌溉水泵', 'pump', 1),
(9, 4, 'D004-LED', '补光灯组', 'led', 2),
(10, 4, 'D004-FAN', '通风风扇', 'fan', 1),
-- 西果园 A区
(11, 5, 'D005-PUMP', '灌溉水泵', 'pump', 0),
-- 西果园 B区
(12, 6, 'D006-PUMP', '灌溉水泵', 'pump', 1),
-- 2号温室大棚 A区
(13, 7, 'D007-PUMP', '灌溉水泵', 'pump', 1),
(14, 7, 'D007-LED', '补光灯组', 'led', 0),
(15, 7, 'D007-FAN', '通风风扇', 'fan', 2),
-- 2号温室大棚 B区
(16, 8, 'D008-PUMP', '灌溉水泵', 'pump', 1),
(17, 8, 'D008-LED', '补光灯组', 'led', 1),
(18, 8, 'D008-FAN', '通风风扇', 'fan', 1),
-- 南区菜地 A区
(19, 9, 'D009-PUMP', '灌溉水泵', 'pump', 1),
-- 南区菜地 B区
(20, 10, 'D010-PUMP', '灌溉水泵', 'pump', 0);

-- =====================
-- 4. 环境历史数据 (sensor_data)
-- 生成过去7天的数据，每小时一条记录
-- =====================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS generate_sensor_data()
BEGIN
    DECLARE v_datetime DATETIME;
    DECLARE v_days INT;
    DECLARE v_hours INT;
    DECLARE v_point_id BIGINT DEFAULT 1;
    DECLARE v_max_point_id INT;
    
    SET v_max_point_id = 10;  -- 最大检测点ID
    
    -- 删除旧测试数据
    DELETE FROM sensor_data WHERE created_at < CURDATE();
    
    -- 为每个检测点生成数据
    SET v_point_id = 1;
    WHILE v_point_id <= v_max_point_id DO
        SET v_days = 0;
        
        -- 生成过去7天的数据
        WHILE v_days < 7 DO
            SET v_hours = 0;
            WHILE v_hours < 24 DO
                SET v_datetime = DATE_SUB(NOW(), INTERVAL v_days DAY) + INTERVAL v_hours HOUR;
                
                -- 根据检测点类型生成不同的数据特征
                INSERT INTO sensor_data (point_id, temperature, humidity, light, co2, soil_moisture, recorded_at, created_at)
                VALUES (
                    v_point_id,
                    ROUND(20 + RAND() * 15, 2),                    -- 温度: 20-35°C
                    ROUND(40 + RAND() * 40, 2),                     -- 湿度: 40-80%
                    ROUND(
                        CASE 
                            WHEN v_hours BETWEEN 6 AND 18 THEN 5000 + RAND() * 45000  -- 白天: 5000-50000 lux
                            ELSE 100 + RAND() * 500                   -- 夜晚: 100-600 lux
                        END, 2
                    ),
                    ROUND(400 + RAND() * 600, 2),                    -- CO2: 400-1000 ppm
                    ROUND(30 + RAND() * 40, 2),                      -- 土壤湿度: 30-70%
                    v_datetime,
                    v_datetime
                );
                
                SET v_hours = v_hours + 1;
            END WHILE;
            SET v_days = v_days + 1;
        END WHILE;
        
        SET v_point_id = v_point_id + 1;
    END WHILE;
    
    SELECT CONCAT('生成 ', (SELECT COUNT(*) FROM sensor_data), ' 条环境历史数据') AS result;
END //
DELIMITER ;

CALL generate_sensor_data();
DROP PROCEDURE IF EXISTS generate_sensor_data;

-- =====================
-- 5. 灌溉记录 (irrigation_log)
-- 生成过去7天的灌溉记录
-- =====================

INSERT INTO irrigation_log (point_id, water_amount, duration, mode, start_time, end_time, created_at) VALUES
-- 东区稻田 A区
(1, 15.5, 62, 0, DATE_SUB(NOW(), INTERVAL 6 HOUR), DATE_SUB(NOW(), INTERVAL 5 HOUR), DATE_SUB(NOW(), INTERVAL 6 HOUR)),
(1, 22.0, 88, 1, DATE_SUB(NOW(), INTERVAL 3 HOUR), DATE_SUB(NOW(), INTERVAL 2 HOUR), DATE_SUB(NOW(), INTERVAL 3 HOUR)),
(1, 18.0, 72, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR),
(1, 25.0, 100, 0, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 6 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 6 HOUR),
-- 东区稻田 B区
(2, 20.0, 80, 0, DATE_SUB(NOW(), INTERVAL 5 HOUR), DATE_SUB(NOW(), INTERVAL 4 HOUR), DATE_SUB(NOW(), INTERVAL 5 HOUR)),
(2, 18.0, 72, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR),
-- 1号温室大棚 A区
(3, 8.0, 32, 0, DATE_SUB(NOW(), INTERVAL 4 HOUR), DATE_SUB(NOW(), INTERVAL 3.5 HOUR), DATE_SUB(NOW(), INTERVAL 4 HOUR)),
(3, 10.0, 40, 1, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 11 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR),
(3, 12.0, 48, 0, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 9 HOUR),
-- 1号温室大棚 B区
(4, 6.5, 26, 0, DATE_SUB(NOW(), INTERVAL 7 HOUR), DATE_SUB(NOW(), INTERVAL 6.5 HOUR), DATE_SUB(NOW(), INTERVAL 7 HOUR)),
(4, 8.0, 32, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 11 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 12 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 11 HOUR),
-- 西果园 A区
(5, 30.0, 120, 0, DATE_SUB(NOW(), INTERVAL 8 HOUR), DATE_SUB(NOW(), INTERVAL 6 HOUR), DATE_SUB(NOW(), INTERVAL 8 HOUR)),
(5, 35.0, 140, 0, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 7 HOUR),
-- 西果园 B区
(6, 28.0, 112, 0, DATE_SUB(NOW(), INTERVAL 10 HOUR), DATE_SUB(NOW(), INTERVAL 8 HOUR), DATE_SUB(NOW(), INTERVAL 10 HOUR)),
(6, 32.0, 128, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR),
-- 2号温室大棚 A区
(7, 5.0, 20, 1, DATE_SUB(NOW(), INTERVAL 2 HOUR), DATE_SUB(NOW(), INTERVAL 1.5 HOUR), DATE_SUB(NOW(), INTERVAL 2 HOUR)),
(7, 7.0, 28, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 9 HOUR),
-- 2号温室大棚 B区
(8, 6.0, 24, 0, DATE_SUB(NOW(), INTERVAL 3 HOUR), DATE_SUB(NOW(), INTERVAL 2.5 HOUR), DATE_SUB(NOW(), INTERVAL 3 HOUR)),
(8, 8.0, 32, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 11 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR),
-- 南区菜地 A区
(9, 12.0, 48, 0, DATE_SUB(NOW(), INTERVAL 5 HOUR), DATE_SUB(NOW(), INTERVAL 4 HOUR), DATE_SUB(NOW(), INTERVAL 5 HOUR)),
(9, 15.0, 60, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR),
-- 南区菜地 B区
(10, 10.0, 40, 1, DATE_SUB(NOW(), INTERVAL 6 HOUR), DATE_SUB(NOW(), INTERVAL 5 HOUR), DATE_SUB(NOW(), INTERVAL 6 HOUR)),
(10, 12.0, 48, 0, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 8 HOUR);

-- =====================
-- 6. 报警记录 (alarm)
-- 生成各类报警历史记录
-- =====================

INSERT INTO alarm (point_id, alarm_type, alarm_value, threshold, status, created_at, handled_at) VALUES
-- 东区稻田 A区
(1, 'TEMPERATURE_HIGH', 38.5, 35.0, 1, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 14 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 15 HOUR),
(1, 'SOIL_MOISTURE_LOW', 25.0, 30.0, 1, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 11 HOUR),
(1, 'TEMPERATURE_HIGH', 37.8, 35.0, 0, DATE_SUB(NOW(), INTERVAL 2 HOUR), NULL),
-- 东区稻田 B区
(2, 'HUMIDITY_LOW', 28.0, 35.0, 1, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 11 HOUR, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 12 HOUR),
(2, 'SOIL_MOISTURE_LOW', 22.0, 30.0, 0, DATE_SUB(NOW(), INTERVAL 1 HOUR), NULL),
-- 1号温室大棚 A区
(3, 'TEMPERATURE_HIGH', 36.2, 35.0, 1, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 13 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 14 HOUR),
(3, 'CO2_HIGH', 1850.0, 1500.0, 1, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 16 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 17 HOUR),
(3, 'HUMIDITY_HIGH', 85.0, 80.0, 0, DATE_SUB(NOW(), INTERVAL 30 MINUTE), NULL),
-- 1号温室大棚 B区
(4, 'LIGHT_LOW', 80.0, 200.0, 1, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 6 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 7 HOUR),
(4, 'TEMPERATURE_LOW', 12.5, 15.0, 1, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 5 HOUR, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 6 HOUR),
-- 西果园 A区
(5, 'TEMPERATURE_HIGH', 39.0, 35.0, 0, DATE_SUB(NOW(), INTERVAL 1 HOUR), NULL),
(5, 'SOIL_MOISTURE_LOW', 20.0, 30.0, 1, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 11 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 12 HOUR),
-- 西果园 B区
(6, 'HUMIDITY_LOW', 25.0, 35.0, 0, DATE_SUB(NOW(), INTERVAL 45 MINUTE), NULL),
-- 2号温室大棚 A区
(7, 'CO2_HIGH', 1620.0, 1500.0, 0, DATE_SUB(NOW(), INTERVAL 15 MINUTE), NULL),
(7, 'TEMPERATURE_HIGH', 37.0, 35.0, 1, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 14 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 15 HOUR),
-- 2号温室大棚 B区
(8, 'LIGHT_LOW', 150.0, 200.0, 1, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 6 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR),
-- 南区菜地 A区
(9, 'SOIL_MOISTURE_LOW', 28.0, 30.0, 0, DATE_SUB(NOW(), INTERVAL 20 MINUTE), NULL),
-- 南区菜地 B区
(10, 'TEMPERATURE_HIGH', 38.0, 35.0, 0, DATE_SUB(NOW(), INTERVAL 3 HOUR), NULL);

-- =====================
-- 7. 验证数据
-- =====================

SELECT '数据生成完成！' AS message;

SELECT '地块统计' AS category, COUNT(*) AS count FROM field
UNION ALL
SELECT '检测点统计', COUNT(*) FROM monitor_point
UNION ALL
SELECT '设备统计', COUNT(*) FROM device
UNION ALL
SELECT '环境数据统计', COUNT(*) FROM sensor_data
UNION ALL
SELECT '灌溉记录统计', COUNT(*) FROM irrigation_log
UNION ALL
SELECT '报警记录统计', COUNT(*) FROM alarm;

-- 显示各地块的检测点数量
SELECT 
    f.field_name AS '地块名称',
    f.field_type AS '类型',
    f.area AS '面积',
    COUNT(p.id) AS '检测点数',
    SUM(CASE WHEN d.status = 2 THEN 1 ELSE 0 END) AS '工作中设备'
FROM field f
LEFT JOIN monitor_point p ON f.id = p.field_id
LEFT JOIN device d ON p.id = d.point_id
GROUP BY f.id
ORDER BY f.id;

-- 显示报警统计
SELECT 
    f.field_name AS '地块',
    a.alarm_type AS '报警类型',
    COUNT(*) AS '次数',
    SUM(CASE WHEN a.status = 0 THEN 1 ELSE 0 END) AS '未处理',
    SUM(CASE WHEN a.status = 1 THEN 1 ELSE 0 END) AS '已处理'
FROM alarm a
JOIN monitor_point p ON a.point_id = p.id
JOIN field f ON p.field_id = f.id
GROUP BY f.field_name, a.alarm_type;
