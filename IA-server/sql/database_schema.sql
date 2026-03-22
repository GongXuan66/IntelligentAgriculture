-- ============================================================
-- 智慧农业控制系统数据库设计
-- 版本: 3.0 (优化版 - 14张表)
-- 更新日期: 2026-03-22
-- 说明: 支持多用户、多农场、智能灌溉、AI助手
-- ============================================================

-- 创建数据库
CREATE DATABASE IF NOT EXISTS agriculture
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE agriculture;

-- ============================================================
-- 第一部分：用户与租户管理（2张表）
-- ============================================================

-- 1. 用户表
CREATE TABLE user (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE COMMENT '用户名/手机号',
    password_hash VARCHAR(100) NOT NULL COMMENT '密码哈希',
    nickname VARCHAR(50) COMMENT '昵称',
    phone VARCHAR(20) COMMENT '手机号',
    email VARCHAR(100) COMMENT '邮箱',
    avatar_url VARCHAR(255) COMMENT '头像URL',
    role VARCHAR(20) DEFAULT 'farmer' COMMENT '角色: admin/farmer/operator',
    status TINYINT DEFAULT 1 COMMENT '状态: 0禁用 1启用',
    last_login_at DATETIME COMMENT '最后登录时间',
    last_login_ip VARCHAR(50) COMMENT '最后登录IP',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_phone (phone),
    INDEX idx_status (status)
) COMMENT '用户表';

-- 2. 农场表
CREATE TABLE farm (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '所属用户ID',
    farm_name VARCHAR(100) NOT NULL COMMENT '农场名称',
    farm_code VARCHAR(50) COMMENT '农场编码',
    location VARCHAR(200) COMMENT '地址',
    province VARCHAR(50) COMMENT '省份',
    city VARCHAR(50) COMMENT '城市',
    area DECIMAL(10,2) COMMENT '总面积(亩)',
    description TEXT COMMENT '农场描述',
    status TINYINT DEFAULT 1 COMMENT '状态: 0停用 1启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_user (user_id),
    INDEX idx_status (status)
) COMMENT '农场表';

-- ============================================================
-- 第二部分：基础业务表（5张表）
-- ============================================================

-- 3. 检测点/地块表
CREATE TABLE monitor_point (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    farm_id BIGINT NOT NULL COMMENT '所属农场ID',
    point_code VARCHAR(50) COMMENT '检测点编码',
    point_name VARCHAR(100) NOT NULL COMMENT '检测点名称',
    location VARCHAR(200) COMMENT '位置描述',
    area DECIMAL(10,2) COMMENT '面积(亩)',
    soil_type VARCHAR(30) COMMENT '土壤类型: sandy/clay/loam',
    status TINYINT DEFAULT 1 COMMENT '状态: 0停用 1启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_farm (farm_id),
    INDEX idx_status (status)
) COMMENT '检测点/地块表';

-- 4. 设备表
CREATE TABLE device (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '所属检测点ID',
    device_code VARCHAR(50) NOT NULL UNIQUE COMMENT '设备编码',
    device_name VARCHAR(100) NOT NULL COMMENT '设备名称',
    device_type VARCHAR(30) NOT NULL COMMENT '设备类型: pump/valve/led/fan/sensor',
    device_model VARCHAR(50) COMMENT '设备型号',
    manufacturer VARCHAR(100) COMMENT '厂商',
    status TINYINT DEFAULT 0 COMMENT '状态: 0离线 1在线 2工作中 3故障',
    last_heartbeat DATETIME COMMENT '最后心跳时间',
    installed_at DATE COMMENT '安装日期',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_point (point_id),
    INDEX idx_device_type (device_type),
    INDEX idx_status (status)
) COMMENT '设备表';

-- 5. 传感器数据表
CREATE TABLE sensor_data (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    temperature DECIMAL(5,2) COMMENT '温度(℃)',
    humidity DECIMAL(5,2) COMMENT '空气湿度(%)',
    light DECIMAL(10,2) COMMENT '光照(lux)',
    co2 DECIMAL(8,2) COMMENT 'CO₂(ppm)',
    soil_moisture DECIMAL(5,2) COMMENT '土壤湿度(%)',
    soil_temperature DECIMAL(5,2) COMMENT '土壤温度(℃)',
    soil_ph DECIMAL(4,2) COMMENT '土壤pH值',
    soil_ec DECIMAL(8,2) COMMENT '土壤EC值(电导率)',
    recorded_at DATETIME NOT NULL COMMENT '记录时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_point_time (point_id, recorded_at),
    INDEX idx_recorded_at (recorded_at)
) COMMENT '传感器数据表';

-- 6. 灌溉记录表（合并了决策记录）
CREATE TABLE irrigation_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    water_amount DECIMAL(10,2) COMMENT '灌溉水量(L)',
    duration INT COMMENT '持续时间(秒)',
    mode TINYINT DEFAULT 0 COMMENT '模式: 0自动 1手动',
    -- 决策相关字段（合并自 smart_irrigation_decision）
    decision_type VARCHAR(30) COMMENT '决策类型: predictive/adaptive/stage_based/manual',
    current_moisture DECIMAL(5,2) COMMENT '决策时湿度',
    predicted_moisture DECIMAL(5,2) COMMENT '预测湿度',
    prediction_hours INT COMMENT '预测时长(小时)',
    crop_stage VARCHAR(30) COMMENT '作物生长阶段',
    irrigation_factor DECIMAL(5,2) COMMENT '灌溉系数',
    confidence DECIMAL(5,2) COMMENT '决策置信度',
    -- 灌溉效果
    soil_moisture_before DECIMAL(5,2) COMMENT '灌溉前土壤湿度',
    soil_moisture_after DECIMAL(5,2) COMMENT '灌溉后土壤湿度',
    temperature DECIMAL(5,2) COMMENT '灌溉时温度',
    humidity DECIMAL(5,2) COMMENT '灌溉时空气湿度',
    trigger_reason VARCHAR(200) COMMENT '触发原因',
    start_time DATETIME NOT NULL COMMENT '开始时间',
    end_time DATETIME COMMENT '结束时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_point_start (point_id, start_time),
    INDEX idx_mode (mode),
    INDEX idx_decision_type (decision_type)
) COMMENT '灌溉记录表';

-- 7. 报警记录表
CREATE TABLE alarm (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    alarm_type VARCHAR(50) NOT NULL COMMENT '报警类型',
    alarm_level TINYINT DEFAULT 1 COMMENT '报警级别: 1一般 2警告 3严重',
    alarm_value DECIMAL(10,2) COMMENT '报警数值',
    threshold DECIMAL(10,2) COMMENT '阈值',
    message VARCHAR(200) COMMENT '报警信息',
    status TINYINT DEFAULT 0 COMMENT '状态: 0未处理 1已处理 2已忽略',
    handled_by BIGINT COMMENT '处理人ID',
    handled_at DATETIME COMMENT '处理时间',
    handle_note VARCHAR(200) COMMENT '处理备注',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_point_status (point_id, status),
    INDEX idx_level (alarm_level),
    INDEX idx_created (created_at)
) COMMENT '报警记录表';

-- ============================================================
-- 第三部分：智能灌溉系统（4张表）
-- ============================================================

-- 8. 作物类型表
CREATE TABLE crop_type (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    crop_code VARCHAR(50) NOT NULL UNIQUE COMMENT '作物编码',
    crop_name VARCHAR(100) NOT NULL COMMENT '作物名称',
    category VARCHAR(30) COMMENT '分类: vegetable/fruit/grain',
    growth_cycle_days INT COMMENT '生长周期(天)',
    water_requirement VARCHAR(20) COMMENT '需水特性: low/medium/high',
    temperature_range VARCHAR(50) COMMENT '适宜温度范围',
    icon_url VARCHAR(255) COMMENT '图标URL',
    description TEXT COMMENT '描述',
    is_active TINYINT DEFAULT 1 COMMENT '是否启用',
    sort_order INT DEFAULT 0 COMMENT '排序',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
) COMMENT '作物类型表';

-- 9. 作物生长阶段配置表
CREATE TABLE crop_stage_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    crop_code VARCHAR(50) NOT NULL COMMENT '作物编码',
    stage_code VARCHAR(30) NOT NULL COMMENT '阶段编码',
    stage_name VARCHAR(30) NOT NULL COMMENT '阶段名称',
    stage_order INT NOT NULL COMMENT '阶段顺序',
    start_day INT NOT NULL COMMENT '开始天数',
    end_day INT NOT NULL COMMENT '结束天数',
    min_humidity DECIMAL(5,2) COMMENT '最低土壤湿度(%)',
    max_humidity DECIMAL(5,2) COMMENT '最高土壤湿度(%)',
    optimal_humidity DECIMAL(5,2) COMMENT '最佳土壤湿度(%)',
    irrigation_factor DECIMAL(5,2) DEFAULT 1.00 COMMENT '灌溉系数',
    frequency_hint VARCHAR(100) COMMENT '灌溉频率建议',
    water_needs VARCHAR(50) COMMENT '需水特点',
    special_notes TEXT COMMENT '特殊注意事项',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_crop_stage (crop_code, stage_code),
    INDEX idx_crop_code (crop_code)
) COMMENT '作物生长阶段配置表';

-- 10. 作物种植信息表
CREATE TABLE crop_planting (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL COMMENT '检测点ID',
    crop_code VARCHAR(50) NOT NULL COMMENT '作物编码',
    crop_name VARCHAR(100) COMMENT '作物名称',
    variety VARCHAR(100) COMMENT '品种',
    planting_date DATE NOT NULL COMMENT '播种日期',
    expected_harvest_date DATE COMMENT '预计收获日期',
    current_stage VARCHAR(30) COMMENT '当前生长阶段',
    current_stage_day INT COMMENT '当前阶段天数',
    stage_updated_at DATE COMMENT '阶段更新日期',
    status TINYINT DEFAULT 1 COMMENT '状态: 0已收获 1生长中',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_point_active (point_id, status),
    INDEX idx_crop_code (crop_code),
    INDEX idx_status (status)
) COMMENT '作物种植信息表';

-- 11. 灌溉阈值配置表
CREATE TABLE irrigation_threshold_config (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    point_id BIGINT NOT NULL UNIQUE COMMENT '检测点ID',
    -- 阈值配置
    moisture_threshold INT DEFAULT 40 COMMENT '湿度阈值(%)',
    max_single_irrigation INT DEFAULT 180 COMMENT '单次最大灌溉时长(秒)',
    min_irrigation_interval INT DEFAULT 30 COMMENT '最小灌溉间隔(分钟)',
    -- 功能开关
    enable_predictive TINYINT DEFAULT 1 COMMENT '启用预测灌溉',
    enable_auto_control TINYINT DEFAULT 1 COMMENT '启用自动控制',
    prediction_mode VARCHAR(20) DEFAULT 'ewma' COMMENT '预测模式: ewma/lstm',
    -- 学习参数
    learned_moisture_gain DECIMAL(6,4) DEFAULT 1.5000 COMMENT '学习到的湿度提升率',
    learning_sample_count INT DEFAULT 0 COMMENT '学习样本数',
    learning_confidence DECIMAL(3,2) DEFAULT 0.00 COMMENT '学习置信度',
    last_learning_at DATETIME COMMENT '最后学习时间',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT '灌溉阈值配置表';

-- ============================================================
-- 第四部分：AI智能助手（1张表 - 合并优化）
-- ============================================================

-- 12. AI交互记录表（合并 chat_history + ai_recommendation + ai_analysis_report）
CREATE TABLE ai_interaction (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    user_id BIGINT NOT NULL COMMENT '用户ID',
    point_id BIGINT COMMENT '相关检测点ID',
    -- 交互类型
    interaction_type VARCHAR(30) NOT NULL COMMENT '类型: chat/recommendation/report',
    -- 会话信息（对话用）
    session_id VARCHAR(100) COMMENT '会话ID',
    role VARCHAR(20) COMMENT '角色: user/assistant/system',
    -- 内容
    title VARCHAR(200) COMMENT '标题（推荐/报告用）',
    content TEXT NOT NULL COMMENT '内容',
    report_type VARCHAR(30) COMMENT '报告类型: daily/weekly/monthly',
    report_date DATE COMMENT '报告日期',
    -- 推荐相关
    recommendation_type VARCHAR(30) COMMENT '推荐类型: irrigation/planting/pest/alert',
    confidence DECIMAL(5,2) COMMENT '置信度',
    -- 状态
    status TINYINT DEFAULT 0 COMMENT '状态: 0待处理 1已采纳 2已忽略',
    feedback VARCHAR(200) COMMENT '用户反馈',
    -- 元数据
    token_count INT COMMENT 'Token数量',
    model VARCHAR(50) COMMENT '使用的模型',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_type (user_id, interaction_type),
    INDEX idx_session (session_id, created_at),
    INDEX idx_type_status (interaction_type, status)
) COMMENT 'AI交互记录表';

-- ============================================================
-- 第五部分：初始化数据
-- ============================================================

-- 默认管理员用户
INSERT INTO user (username, password_hash, nickname, phone, role, status) VALUES
('admin', '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8iAt6Z5EHsM8lE9lBOsl7iAt6Z5EH', '系统管理员', '13800000000', 'admin', 1);

-- 作物类型初始数据
INSERT INTO crop_type (crop_code, crop_name, category, growth_cycle_days, water_requirement, sort_order) VALUES
('tomato', '番茄', 'vegetable', 120, 'medium', 1),
('cucumber', '黄瓜', 'vegetable', 80, 'high', 2),
('pepper', '辣椒', 'vegetable', 100, 'medium', 3),
('eggplant', '茄子', 'vegetable', 110, 'medium', 4),
('rice', '水稻', 'grain', 120, 'high', 5),
('corn', '玉米', 'grain', 100, 'medium', 6),
('vegetable', '通用蔬菜', 'vegetable', 90, 'medium', 7),
('strawberry', '草莓', 'fruit', 150, 'high', 8),
('watermelon', '西瓜', 'fruit', 100, 'medium', 9),
('cabbage', '白菜', 'vegetable', 70, 'medium', 10);

-- 作物生长阶段配置数据
INSERT INTO crop_stage_config (crop_code, stage_code, stage_name, stage_order, start_day, end_day, min_humidity, max_humidity, optimal_humidity, irrigation_factor, frequency_hint, water_needs, special_notes) VALUES
-- 番茄
('tomato', 'sowing', '播种期', 1, 0, 7, 60.00, 75.00, 65.00, 1.20, '每天2-3次少量', '高频少量', '保持表层湿润'),
('tomato', 'seedling', '幼苗期', 2, 7, 30, 50.00, 65.00, 55.00, 0.90, '每2天1次', '适度控水', '促进根系发育'),
('tomato', 'flowering', '开花期', 3, 30, 50, 40.00, 55.00, 48.00, 0.70, '精准控制', '敏感期', '避免过湿落花'),
('tomato', 'fruiting', '结果期', 4, 50, 90, 50.00, 70.00, 60.00, 1.10, '每天1-2次', '需水量最大', '保证水分供应'),
('tomato', 'mature', '成熟期', 5, 90, 120, 40.00, 55.00, 48.00, 0.80, '适当减少', '控水提质', '提高果实糖度'),

-- 黄瓜
('cucumber', 'sowing', '播种期', 1, 0, 5, 65.00, 80.00, 70.00, 1.30, '每天多次少量', '喜湿', '保持湿润'),
('cucumber', 'seedling', '幼苗期', 2, 5, 25, 55.00, 70.00, 62.00, 1.00, '每天1次', '需水较大', '促进茎叶生长'),
('cucumber', 'flowering', '开花期', 3, 25, 40, 50.00, 65.00, 57.00, 0.80, '适中控制', '避免过湿', '避免影响授粉'),
('cucumber', 'fruiting', '结果期', 4, 40, 80, 55.00, 75.00, 65.00, 1.20, '每天2次', '需水量大', '保证产量'),

-- 辣椒
('pepper', 'sowing', '播种期', 1, 0, 10, 55.00, 70.00, 60.00, 1.10, '每天1-2次少量', '适中', '促进发芽'),
('pepper', 'seedling', '幼苗期', 2, 10, 35, 45.00, 60.00, 52.00, 0.85, '每2天1次', '适度控水', '促进根系'),
('pepper', 'flowering', '开花期', 3, 35, 55, 40.00, 55.00, 47.00, 0.75, '精准控制', '敏感期', '避免落花'),
('pepper', 'fruiting', '结果期', 4, 55, 100, 50.00, 65.00, 57.00, 1.05, '每天1次', '需水增加', '保证结果'),

-- 茄子
('eggplant', 'sowing', '播种期', 1, 0, 10, 55.00, 70.00, 62.00, 1.10, '每天1-2次', '保持湿润', '促进发芽'),
('eggplant', 'seedling', '幼苗期', 2, 10, 40, 45.00, 60.00, 52.00, 0.90, '每2天1次', '适中需水', '促进根系'),
('eggplant', 'flowering', '开花期', 3, 40, 60, 45.00, 58.00, 50.00, 0.85, '适中控制', '避免过湿', '稳定环境'),
('eggplant', 'fruiting', '结果期', 4, 60, 110, 50.00, 68.00, 58.00, 1.10, '每天1次', '需水量大', '保证产量'),

-- 水稻
('rice', 'sowing', '播种期', 1, 0, 10, 80.00, 95.00, 90.00, 1.50, '保持水层', '水生作物', '保持浅水层'),
('rice', 'tillering', '分蘖期', 2, 10, 40, 70.00, 90.00, 80.00, 1.20, '浅水层', '促进分蘖', '浅水管理'),
('rice', 'jointing', '拔节期', 3, 40, 60, 60.00, 80.00, 70.00, 1.00, '干湿交替', '适度晒田', '增强根系'),
('rice', 'heading', '抽穗期', 4, 60, 75, 75.00, 90.00, 82.00, 1.30, '保持水层', '关键期', '保证水分'),
('rice', 'mature', '成熟期', 5, 75, 110, 50.00, 70.00, 60.00, 0.70, '逐渐排水', '便于收获', '排水晒田'),

-- 玉米
('corn', 'sowing', '播种期', 1, 0, 7, 55.00, 70.00, 62.00, 1.10, '保持湿润', '促进发芽', '适宜墒情'),
('corn', 'seedling', '苗期', 2, 7, 30, 45.00, 60.00, 52.00, 0.85, '适当控水', '促根下扎', '适度干旱'),
('corn', 'jointing', '拔节期', 3, 30, 50, 50.00, 68.00, 58.00, 1.05, '增加供水', '需水增加', '及时灌溉'),
('corn', 'tasseling', '抽穗期', 4, 50, 70, 55.00, 75.00, 65.00, 1.25, '充足供水', '需水关键期', '保证充足'),
('corn', 'filling', '灌浆期', 5, 70, 100, 50.00, 68.00, 58.00, 1.00, '适中供水', '保证灌浆', '稳定供水'),

-- 通用蔬菜
('vegetable', 'seedling', '苗期', 1, 0, 20, 50.00, 65.00, 57.00, 0.95, '每天1次', '适中需水', '保持湿润'),
('vegetable', 'growing', '生长期', 2, 20, 60, 45.00, 65.00, 55.00, 1.00, '每1-2天1次', '正常需水', '正常灌溉'),
('vegetable', 'harvest', '收获期', 3, 60, 90, 45.00, 60.00, 52.00, 0.85, '适当减少', '控水提质', '提高品质'),

-- 草莓
('strawberry', 'seedling', '苗期', 1, 0, 20, 55.00, 70.00, 62.00, 1.00, '每天1次', '适中需水', '促进根系'),
('strawberry', 'flowering', '开花期', 2, 20, 50, 50.00, 65.00, 57.00, 0.85, '精准控制', '敏感期', '避免过湿'),
('strawberry', 'fruiting', '结果期', 3, 50, 120, 55.00, 70.00, 62.00, 1.10, '每天1次', '需水较大', '保证品质'),
('strawberry', 'harvest', '收获期', 4, 120, 150, 50.00, 60.00, 55.00, 0.80, '适当减少', '控糖提质', '提高甜度'),

-- 西瓜
('watermelon', 'sowing', '播种期', 1, 0, 7, 55.00, 70.00, 62.00, 1.10, '保持湿润', '促进发芽', '适宜温度'),
('watermelon', 'seedling', '幼苗期', 2, 7, 30, 45.00, 60.00, 52.00, 0.85, '适当控水', '促根壮苗', '适度干旱'),
('watermelon', 'vining', '伸蔓期', 3, 30, 50, 50.00, 65.00, 57.00, 1.00, '适中供水', '促进生长', '均衡供水'),
('watermelon', 'fruiting', '结果期', 4, 50, 80, 55.00, 70.00, 62.00, 1.15, '充足供水', '需水关键', '保证产量'),
('watermelon', 'mature', '成熟期', 5, 80, 100, 40.00, 55.00, 48.00, 0.70, '控水提质', '提高糖度', '采收前停水'),

-- 白菜
('cabbage', 'sowing', '播种期', 1, 0, 7, 55.00, 70.00, 62.00, 1.10, '每天2次少量', '保持湿润', '促进发芽'),
('cabbage', 'seedling', '幼苗期', 2, 7, 25, 50.00, 65.00, 57.00, 0.95, '每天1次', '适中需水', '促进生长'),
('cabbage', 'rosette', '莲座期', 3, 25, 50, 55.00, 70.00, 62.00, 1.05, '充足供水', '需水增加', '促进结球'),
('cabbage', 'heading', '结球期', 4, 50, 70, 55.00, 70.00, 62.00, 1.10, '每天1次', '需水量大', '保证紧实');

-- ============================================================
-- 第六部分：视图（便于查询）
-- ============================================================

-- 当前种植作物视图
CREATE OR REPLACE VIEW v_current_planting AS
SELECT 
    cp.id,
    cp.point_id,
    mp.point_name,
    mp.farm_id,
    f.farm_name,
    f.user_id,
    u.nickname as owner_name,
    cp.crop_code,
    cp.crop_name,
    cp.variety,
    cp.planting_date,
    cp.current_stage,
    cp.current_stage_day,
    DATEDIFF(CURDATE(), cp.planting_date) as days_since_planting,
    csc.min_humidity,
    csc.max_humidity,
    csc.optimal_humidity,
    csc.irrigation_factor
FROM crop_planting cp
JOIN monitor_point mp ON cp.point_id = mp.id
JOIN farm f ON mp.farm_id = f.id
JOIN user u ON f.user_id = u.id
LEFT JOIN crop_stage_config csc ON cp.crop_code = csc.crop_code 
    AND csc.start_day <= DATEDIFF(CURDATE(), cp.planting_date)
    AND csc.end_day >= DATEDIFF(CURDATE(), cp.planting_date)
WHERE cp.status = 1;

-- 灌溉效果分析视图
CREATE OR REPLACE VIEW v_irrigation_effect AS
SELECT 
    il.point_id,
    mp.point_name,
    mp.farm_id,
    DATE(il.start_time) as irrigation_date,
    COUNT(*) as irrigation_count,
    SUM(il.water_amount) as total_water,
    AVG(il.duration) as avg_duration,
    AVG(il.soil_moisture_after - il.soil_moisture_before) as avg_moisture_gain,
    AVG(CASE WHEN il.soil_moisture_after IS NOT NULL AND il.water_amount > 0 
        THEN (il.soil_moisture_after - il.soil_moisture_before) / il.water_amount 
        ELSE NULL END) as actual_gain_per_liter
FROM irrigation_log il
JOIN monitor_point mp ON il.point_id = mp.id
WHERE il.soil_moisture_before IS NOT NULL 
    AND il.soil_moisture_after IS NOT NULL
GROUP BY il.point_id, mp.point_name, mp.farm_id, DATE(il.start_time);

-- 设备状态视图
CREATE OR REPLACE VIEW v_device_status AS
SELECT 
    d.id,
    d.device_code,
    d.device_name,
    d.device_type,
    d.status,
    d.last_heartbeat,
    CASE 
        WHEN d.last_heartbeat IS NULL THEN '从未在线'
        WHEN d.last_heartbeat < DATE_SUB(NOW(), INTERVAL 5 MINUTE) THEN '离线'
        ELSE '在线'
    END as online_status,
    mp.point_name,
    f.farm_name,
    u.nickname as owner_name
FROM device d
JOIN monitor_point mp ON d.point_id = mp.id
JOIN farm f ON mp.farm_id = f.id
JOIN user u ON f.user_id = u.id;
