-- 创建数据库
CREATE DATABASE IF NOT EXISTS agriculture
    DEFAULT CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE agriculture;

-- 检测点表
CREATE TABLE monitor_point (
                               id BIGINT PRIMARY KEY AUTO_INCREMENT,
                               point_id VARCHAR(50) NOT NULL UNIQUE COMMENT '检测点ID',
                               point_name VARCHAR(100) NOT NULL COMMENT '名称',
                               location VARCHAR(200) COMMENT '位置',
                               crop_type VARCHAR(50) COMMENT '作物类型',
                               status TINYINT DEFAULT 1 COMMENT '状态: 0停用 1启用',
                               created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                               updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT '检测点表';

-- 设备表
CREATE TABLE device (
                        id BIGINT PRIMARY KEY AUTO_INCREMENT,
                        point_id BIGINT NOT NULL COMMENT '所属检测点ID',
                        device_id VARCHAR(50) NOT NULL UNIQUE COMMENT '设备标识',
                        device_name VARCHAR(100) NOT NULL COMMENT '设备名称',
                        device_type VARCHAR(20) NOT NULL COMMENT '类型: pump/led/fan/valve',
                        status TINYINT DEFAULT 0 COMMENT '状态: 0离线 1在线 2工作中',
                        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) COMMENT '设备表';

-- 环境数据表
CREATE TABLE sensor_data (
                             id BIGINT PRIMARY KEY AUTO_INCREMENT,
                             point_id BIGINT NOT NULL COMMENT '检测点ID',
                             temperature DECIMAL(5,2) COMMENT '温度(℃)',
                             humidity DECIMAL(5,2) COMMENT '湿度(%)',
                             light DECIMAL(10,2) COMMENT '光照(lux)',
                             co2 DECIMAL(8,2) COMMENT 'CO₂(ppm)',
                             soil_moisture DECIMAL(5,2) COMMENT '土壤湿度(%)',
                             recorded_at DATETIME NOT NULL COMMENT '记录时间',
                             created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                             INDEX idx_point_time (point_id, recorded_at)
) COMMENT '环境数据表';

-- 灌溉记录表
CREATE TABLE irrigation_log (
                                id BIGINT PRIMARY KEY AUTO_INCREMENT,
                                point_id BIGINT NOT NULL COMMENT '检测点ID',
                                water_amount DECIMAL(10,2) COMMENT '灌溉水量(L)',
                                duration INT COMMENT '持续时间(秒)',
                                mode TINYINT DEFAULT 0 COMMENT '模式: 0自动 1手动',
                                start_time DATETIME NOT NULL COMMENT '开始时间',
                                end_time DATETIME COMMENT '结束时间',
                                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                                INDEX idx_point_start_time (point_id, start_time)
) COMMENT '灌溉记录表';

-- 报警记录表
CREATE TABLE alarm (
                       id BIGINT PRIMARY KEY AUTO_INCREMENT,
                       point_id BIGINT NOT NULL COMMENT '检测点ID',
                       alarm_type VARCHAR(50) NOT NULL COMMENT '报警类型',
                       alarm_value DECIMAL(10,2) COMMENT '报警数值',
                       threshold DECIMAL(10,2) COMMENT '阈值',
                       status TINYINT DEFAULT 0 COMMENT '状态: 0未处理 1已处理',
                       created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                       handled_at DATETIME COMMENT '处理时间',
                       INDEX idx_status (status),
                       INDEX idx_created (created_at),
                       INDEX idx_point_status_created (point_id, status, created_at)
) COMMENT '报警记录表';

-- AI对话历史表
CREATE TABLE chat_history (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    session_id VARCHAR(100) NOT NULL COMMENT '会话ID',
    role VARCHAR(20) NOT NULL COMMENT '角色: user/assistant',
    content TEXT NOT NULL COMMENT '消息内容',
    token_count INT COMMENT 'Token数量',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    INDEX idx_session_created (session_id, created_at)
) COMMENT 'AI对话历史表';
