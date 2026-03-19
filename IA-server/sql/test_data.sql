-- 测试数据生成脚本
-- 使用方法: 在MySQL中执行此脚本

USE agriculture;

-- =====================
-- 1. 环境历史数据 (sensor_data)
-- 生成过去7天的数据，每小时一条记录
-- =====================

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS generate_sensor_data()
BEGIN
    DECLARE v_datetime DATETIME;
    DECLARE v_days INT;
    DECLARE v_hours INT;
    DECLARE v_point_id BIGINT DEFAULT 1;
    
    SET v_days = 0;
    
    -- 删除旧测试数据（保留当天数据）
    DELETE FROM sensor_data WHERE created_at < CURDATE();
    
    -- 生成过去7天的数据
    WHILE v_days < 7 DO
        SET v_hours = 0;
        WHILE v_hours < 24 DO
            SET v_datetime = DATE_SUB(NOW(), INTERVAL v_days DAY) + INTERVAL v_hours HOUR;
            
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
    
    SELECT CONCAT('生成 ', (SELECT COUNT(*) FROM sensor_data WHERE point_id = 1), ' 条环境历史数据') AS result;
END //
DELIMITER ;

CALL generate_sensor_data();
DROP PROCEDURE IF EXISTS generate_sensor_data;

-- =====================
-- 2. 灌溉记录 (irrigation_log)
-- 生成过去7天的灌溉记录
-- =====================

INSERT INTO irrigation_log (point_id, water_amount, duration, mode, start_time, end_time, created_at) VALUES
-- 今天
(1, 15.5, 62, 0, DATE_SUB(NOW(), INTERVAL 6 HOUR), DATE_SUB(NOW(), INTERVAL 5 HOUR), DATE_SUB(NOW(), INTERVAL 6 HOUR)),
(1, 22.0, 88, 1, DATE_SUB(NOW(), INTERVAL 3 HOUR), DATE_SUB(NOW(), INTERVAL 2 HOUR), DATE_SUB(NOW(), INTERVAL 3 HOUR)),
-- 昨天
(1, 18.0, 72, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 7 HOUR),
(1, 20.5, 82, 0, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 14 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 15 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 14 HOUR),
(1, 12.0, 48, 1, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 18 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 19 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 18 HOUR),
-- 2天前
(1, 25.0, 100, 0, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 6 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 6 HOUR),
(1, 15.0, 60, 0, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 15 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 16 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 15 HOUR),
-- 3天前
(1, 30.0, 120, 0, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 8 HOUR),
(1, 10.0, 40, 1, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 16 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 17 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 16 HOUR),
-- 4天前
(1, 20.0, 80, 0, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 7 HOUR),
(1, 18.5, 74, 0, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 14 HOUR, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 15 HOUR, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 14 HOUR),
-- 5天前
(1, 22.5, 90, 0, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 6 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 7 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 6 HOUR),
(1, 16.0, 64, 1, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 17 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 18 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 17 HOUR),
-- 6天前
(1, 28.0, 112, 0, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 8 HOUR, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 8 HOUR),
(1, 14.0, 56, 0, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 16 HOUR, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 17 HOUR, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 16 HOUR);

-- =====================
-- 3. 报警记录 (alarm)
-- 生成各类报警历史记录
-- =====================

INSERT INTO alarm (point_id, alarm_type, alarm_value, threshold, status, created_at, handled_at) VALUES
-- 高温报警
(1, 'TEMPERATURE_HIGH', 38.5, 35.0, 1, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 14 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 15 HOUR),
(1, 'TEMPERATURE_HIGH', 36.2, 35.0, 1, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 13 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 14 HOUR),
(1, 'TEMPERATURE_HIGH', 37.8, 35.0, 0, DATE_SUB(NOW(), INTERVAL 2 HOUR), NULL),
-- 低温报警
(1, 'TEMPERATURE_LOW', 12.5, 15.0, 1, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 5 HOUR, DATE_SUB(NOW(), INTERVAL 6 DAY) + INTERVAL 6 HOUR),
-- 湿度过低
(1, 'HUMIDITY_LOW', 28.0, 35.0, 1, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 11 HOUR, DATE_SUB(NOW(), INTERVAL 4 DAY) + INTERVAL 12 HOUR),
(1, 'HUMIDITY_LOW', 32.5, 35.0, 0, DATE_SUB(NOW(), INTERVAL 1 HOUR), NULL),
-- 土壤湿度过低
(1, 'SOIL_MOISTURE_LOW', 25.0, 30.0, 1, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 10 HOUR, DATE_SUB(NOW(), INTERVAL 2 DAY) + INTERVAL 11 HOUR),
(1, 'SOIL_MOISTURE_LOW', 22.0, 30.0, 1, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 9 HOUR, DATE_SUB(NOW(), INTERVAL 1 DAY) + INTERVAL 10 HOUR),
-- CO2浓度异常
(1, 'CO2_HIGH', 1850.0, 1500.0, 1, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 16 HOUR, DATE_SUB(NOW(), INTERVAL 3 DAY) + INTERVAL 17 HOUR),
(1, 'CO2_HIGH', 1620.0, 1500.0, 0, DATE_SUB(NOW(), INTERVAL 30 MINUTE), NULL),
-- 光照不足
(1, 'LIGHT_LOW', 80.0, 200.0, 1, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 6 HOUR, DATE_SUB(NOW(), INTERVAL 5 DAY) + INTERVAL 7 HOUR);

-- =====================
-- 4. 验证数据
-- =====================

SELECT '数据生成完成！' AS message;
SELECT '环境数据统计' AS category, COUNT(*) AS count, MIN(recorded_at) AS earliest, MAX(recorded_at) AS latest FROM sensor_data WHERE point_id = 1
UNION ALL
SELECT '灌溉记录统计', COUNT(*), MIN(start_time), MAX(start_time) FROM irrigation_log WHERE point_id = 1
UNION ALL
SELECT '报警记录统计', COUNT(*), MIN(created_at), MAX(created_at) FROM alarm WHERE point_id = 1;

-- 显示报警统计
SELECT 
    alarm_type AS '报警类型',
    COUNT(*) AS '次数',
    SUM(CASE WHEN status = 0 THEN 1 ELSE 0 END) AS '未处理',
    SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) AS '已处理'
FROM alarm 
WHERE point_id = 1
GROUP BY alarm_type;
