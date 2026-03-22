-- 智能灌溉算法相关表结构
-- 执行此脚本前请确保已执行 create.sql

USE agriculture;

-- 1. 扩展灌溉记录表，添加效果追踪字段
ALTER TABLE irrigation_log 
    ADD COLUMN soil_moisture_before DECIMAL(5,2) COMMENT '灌溉前土壤湿度' AFTER water_amount,
    ADD COLUMN soil_moisture_after DECIMAL(5,2) COMMENT '灌溉后土壤湿度' AFTER soil_moisture_before,
    ADD COLUMN expected_moisture_gain DECIMAL(5,2) COMMENT '预期湿度提升' AFTER soil_moisture_after,
    ADD COLUMN actual_moisture_gain DECIMAL(5,2) COMMENT '实际湿度提升' AFTER expected_moisture_gain,
    ADD COLUMN temperature DECIMAL(5,2) COMMENT '灌溉时温度' AFTER actual_moisture_gain,
    ADD COLUMN humidity DECIMAL(5,2) COMMENT '灌溉时空气湿度' AFTER temperature,
    ADD COLUMN prediction_mode VARCHAR(20) DEFAULT 'standard' COMMENT '预测模式: standard/ewma/lstm' AFTER humidity;

-- 2. 灌溉学习参数表（自适应学习）
CREATE TABLE irrigation_learning_params (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    param_name VARCHAR(50) NOT NULL COMMENT '参数名称',
    param_value DECIMAL(10,4) NOT NULL COMMENT '参数值',
    sample_count INT DEFAULT 1 COMMENT '样本数量',
    confidence DECIMAL(5,2) DEFAULT 0.30 COMMENT '置信度(0-1)',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_point_param (point_id, param_name),
    INDEX idx_point (point_id)
) COMMENT '灌溉学习参数表';

-- 3. 作物信息表
CREATE TABLE crop_info (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    crop_type VARCHAR(50) NOT NULL COMMENT '作物类型编码',
    crop_name VARCHAR(100) COMMENT '作物名称',
    variety VARCHAR(100) COMMENT '品种',
    planting_date DATE NOT NULL COMMENT '播种日期',
    expected_harvest_date DATE COMMENT '预计收获日期',
    current_stage VARCHAR(30) COMMENT '当前生长阶段',
    stage_updated_at DATE COMMENT '阶段更新日期',
    status TINYINT DEFAULT 1 COMMENT '状态: 0已收获 1生长中',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_point (point_id),
    INDEX idx_crop_type (crop_type),
    INDEX idx_status (status)
) COMMENT '作物信息表';

-- 4. 作物生长阶段配置表（知识库）
CREATE TABLE crop_stage_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    crop_type VARCHAR(50) NOT NULL COMMENT '作物类型编码',
    stage_name VARCHAR(30) NOT NULL COMMENT '阶段名称',
    stage_order INT NOT NULL COMMENT '阶段顺序',
    start_day INT NOT NULL COMMENT '开始天数(播种后)',
    end_day INT NOT NULL COMMENT '结束天数(播种后)',
    min_humidity DECIMAL(5,2) COMMENT '最低土壤湿度(%)',
    max_humidity DECIMAL(5,2) COMMENT '最高土壤湿度(%)',
    optimal_humidity DECIMAL(5,2) COMMENT '最佳土壤湿度(%)',
    irrigation_factor DECIMAL(5,2) DEFAULT 1.00 COMMENT '灌溉系数',
    frequency_hint VARCHAR(100) COMMENT '频率建议',
    water_needs VARCHAR(50) COMMENT '需水特点',
    special_notes TEXT COMMENT '特殊注意事项',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_crop_stage (crop_type, stage_name),
    INDEX idx_crop_type (crop_type)
) COMMENT '作物生长阶段配置表';

-- 5. 预置常见作物配置数据
INSERT INTO crop_stage_config (crop_type, stage_name, stage_order, start_day, end_day, min_humidity, max_humidity, optimal_humidity, irrigation_factor, frequency_hint, water_needs, special_notes) VALUES
-- 番茄 (tomato)
('tomato', '播种期', 1, 0, 7, 60.00, 75.00, 65.00, 1.20, '每天2-3次少量', '高频少量，保持表层湿润', '保持表层湿润，促进发芽，避免积水'),
('tomato', '幼苗期', 2, 7, 30, 50.00, 65.00, 55.00, 0.90, '每2天1次', '适度控水促根', '适度控水促进根系发育，避免徒长'),
('tomato', '开花期', 3, 30, 50, 40.00, 55.00, 48.00, 0.70, '精准控制', '敏感期，避免过湿', '避免过湿导致落花落果，保持稳定'),
('tomato', '结果期', 4, 50, 90, 50.00, 70.00, 60.00, 1.10, '每天1-2次', '需水量最大时期', '需水量最大，保证水分供应充足'),
('tomato', '成熟期', 5, 90, 120, 40.00, 55.00, 48.00, 0.80, '适当减少', '控水提高品质', '适当控水提高果实糖度和品质'),

-- 黄瓜 (cucumber)
('cucumber', '播种期', 1, 0, 5, 65.00, 80.00, 70.00, 1.30, '每天多次少量', '喜湿，保持湿润', '喜湿作物，保持土壤湿润但不积水'),
('cucumber', '幼苗期', 2, 5, 25, 55.00, 70.00, 62.00, 1.00, '每天1次', '需水量较大', '需水量较大，促进茎叶生长'),
('cucumber', '开花期', 3, 25, 40, 50.00, 65.00, 57.00, 0.80, '适中控制', '避免过湿', '避免过湿影响授粉'),
('cucumber', '结果期', 4, 40, 80, 55.00, 75.00, 65.00, 1.20, '每天2次', '需水量大', '需水量大，保证产量'),

-- 辣椒 (pepper)
('pepper', '播种期', 1, 0, 10, 55.00, 70.00, 60.00, 1.10, '每天1-2次少量', '适中湿度', '保持土壤湿润，促进发芽'),
('pepper', '幼苗期', 2, 10, 35, 45.00, 60.00, 52.00, 0.85, '每2天1次', '适度控水', '适度控水促进根系发育'),
('pepper', '开花期', 3, 35, 55, 40.00, 55.00, 47.00, 0.75, '精准控制', '敏感期控水', '避免过湿导致落花'),
('pepper', '结果期', 4, 55, 100, 50.00, 65.00, 57.00, 1.05, '每天1次', '需水量增加', '需水量增加，保证结果'),

-- 茄子 (eggplant)
('eggplant', '播种期', 1, 0, 10, 55.00, 70.00, 62.00, 1.10, '每天1-2次', '保持湿润', '保持土壤湿润'),
('eggplant', '幼苗期', 2, 10, 40, 45.00, 60.00, 52.00, 0.90, '每2天1次', '适中需水', '适中需水，促进根系'),
('eggplant', '开花期', 3, 40, 60, 45.00, 58.00, 50.00, 0.85, '适中控制', '避免过湿', '避免过湿'),
('eggplant', '结果期', 4, 60, 110, 50.00, 68.00, 58.00, 1.10, '每天1次', '需水量大', '需水量大时期'),

-- 水稻 (rice) - 水生作物
('rice', '播种期', 1, 0, 10, 80.00, 95.00, 90.00, 1.50, '保持水层', '水生作物', '保持浅水层'),
('rice', '分蘖期', 2, 10, 40, 70.00, 90.00, 80.00, 1.20, '浅水层', '促进分蘖', '浅水层促进分蘖'),
('rice', '拔节期', 3, 40, 60, 60.00, 80.00, 70.00, 1.00, '干湿交替', '适度晒田', '干湿交替，适度晒田'),
('rice', '抽穗期', 4, 60, 75, 75.00, 90.00, 82.00, 1.30, '保持水层', '关键需水期', '关键需水期，保持水层'),
('rice', '成熟期', 5, 75, 110, 50.00, 70.00, 60.00, 0.70, '逐渐排水', '便于收获', '逐渐排水便于收获'),

-- 玉米 (corn)
('corn', '播种期', 1, 0, 7, 55.00, 70.00, 62.00, 1.10, '保持湿润', '促进发芽', '保持土壤湿润'),
('corn', '苗期', 2, 7, 30, 45.00, 60.00, 52.00, 0.85, '适当控水', '促根下扎', '适当控水促进根系下扎'),
('corn', '拔节期', 3, 30, 50, 50.00, 68.00, 58.00, 1.05, '增加供水', '需水增加', '需水量开始增加'),
('corn', '抽穗期', 4, 50, 70, 55.00, 75.00, 65.00, 1.25, '充足供水', '需水关键期', '需水关键期，保证充足'),
('corn', '灌浆期', 5, 70, 100, 50.00, 68.00, 58.00, 1.00, '适中供水', '保证灌浆', '保证籽粒灌浆'),

-- 蔬菜通用 (vegetable) - 默认配置
('vegetable', '苗期', 1, 0, 20, 50.00, 65.00, 57.00, 0.95, '每天1次', '适中需水', '保持土壤湿润'),
('vegetable', '生长期', 2, 20, 60, 45.00, 65.00, 55.00, 1.00, '每1-2天1次', '正常需水', '正常灌溉'),
('vegetable', '收获期', 3, 60, 90, 45.00, 60.00, 52.00, 0.85, '适当减少', '控水提质', '适当控水提高品质');

-- 6. 智能灌溉决策记录表
CREATE TABLE smart_irrigation_decision (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    decision_type VARCHAR(30) NOT NULL COMMENT '决策类型: predictive/adaptive/stage_based',
    current_moisture DECIMAL(5,2) COMMENT '当前湿度',
    predicted_moisture DECIMAL(5,2) COMMENT '预测湿度',
    prediction_hours INT COMMENT '预测时长(小时)',
    crop_stage VARCHAR(30) COMMENT '作物生长阶段',
    irrigation_factor DECIMAL(5,2) COMMENT '灌溉系数',
    recommended_water DECIMAL(10,2) COMMENT '建议用水量(L)',
    actual_water DECIMAL(10,2) COMMENT '实际用水量(L)',
    confidence DECIMAL(5,2) COMMENT '决策置信度',
    reason TEXT COMMENT '决策理由',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_point_time (point_id, created_at),
    INDEX idx_decision_type (decision_type)
) COMMENT '智能灌溉决策记录表';

-- 7. 初始化默认学习参数
INSERT INTO irrigation_learning_params (point_id, param_name, param_value, sample_count, confidence) VALUES
(1, 'MOISTURE_GAIN_PER_LITER', 1.6667, 1, 0.30),
(1, 'EVAPORATION_RATE', 0.50, 1, 0.25),
(1, 'TEMP_FACTOR', 1.00, 1, 0.30);
