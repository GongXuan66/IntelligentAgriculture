package com.agriculture.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

/**
 * 智能灌溉表结构初始化器
 * 应用启动后自动创建所需的表
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class SmartIrrigationInitializer {

    private final JdbcTemplate jdbcTemplate;

    @EventListener(ApplicationReadyEvent.class)
    public void init() {
        log.info("开始初始化智能灌溉表结构...");
        
        try {
            // 1. 扩展灌溉记录表
            addColumnIfNotExists("irrigation_log", "soil_moisture_before", 
                "DECIMAL(5,2) COMMENT '灌溉前土壤湿度'");
            addColumnIfNotExists("irrigation_log", "soil_moisture_after", 
                "DECIMAL(5,2) COMMENT '灌溉后土壤湿度'");
            addColumnIfNotExists("irrigation_log", "expected_moisture_gain", 
                "DECIMAL(5,2) COMMENT '预期湿度提升'");
            addColumnIfNotExists("irrigation_log", "actual_moisture_gain", 
                "DECIMAL(5,2) COMMENT '实际湿度提升'");
            addColumnIfNotExists("irrigation_log", "temperature", 
                "DECIMAL(5,2) COMMENT '灌溉时温度'");
            addColumnIfNotExists("irrigation_log", "humidity", 
                "DECIMAL(5,2) COMMENT '灌溉时空气湿度'");
            addColumnIfNotExists("irrigation_log", "prediction_mode", 
                "VARCHAR(20) DEFAULT 'standard' COMMENT '预测模式'");
            
            // 2. 创建灌溉学习参数表
            createTableIfNotExists("irrigation_learning_params", """
                (id BIGINT PRIMARY KEY AUTO_INCREMENT,
                point_id BIGINT NOT NULL COMMENT '检测点ID',
                param_name VARCHAR(50) NOT NULL COMMENT '参数名称',
                param_value DECIMAL(10,4) NOT NULL COMMENT '参数值',
                sample_count INT DEFAULT 1 COMMENT '样本数量',
                confidence DECIMAL(5,2) DEFAULT 0.30 COMMENT '置信度',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uk_point_param (point_id, param_name),
                INDEX idx_point (point_id))
                """);
            
            // 3. 创建作物信息表
            createTableIfNotExists("crop_info", """
                (id BIGINT PRIMARY KEY AUTO_INCREMENT,
                point_id BIGINT NOT NULL COMMENT '检测点ID',
                crop_type VARCHAR(50) NOT NULL COMMENT '作物类型编码',
                crop_name VARCHAR(100) COMMENT '作物名称',
                variety VARCHAR(100) COMMENT '品种',
                planting_date DATE NOT NULL COMMENT '播种日期',
                expected_harvest_date DATE COMMENT '预计收获日期',
                current_stage VARCHAR(30) COMMENT '当前生长阶段',
                stage_updated_at DATE COMMENT '阶段更新日期',
                status TINYINT DEFAULT 1 COMMENT '状态',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                UNIQUE KEY uk_point (point_id))
                """);
            
            // 4. 创建作物生长阶段配置表
            createTableIfNotExists("crop_stage_config", """
                (id BIGINT PRIMARY KEY AUTO_INCREMENT,
                crop_type VARCHAR(50) NOT NULL COMMENT '作物类型',
                stage_name VARCHAR(30) NOT NULL COMMENT '阶段名称',
                stage_order INT NOT NULL COMMENT '阶段顺序',
                start_day INT NOT NULL COMMENT '开始天数',
                end_day INT NOT NULL COMMENT '结束天数',
                min_humidity DECIMAL(5,2) COMMENT '最低湿度',
                max_humidity DECIMAL(5,2) COMMENT '最高湿度',
                optimal_humidity DECIMAL(5,2) COMMENT '最佳湿度',
                irrigation_factor DECIMAL(5,2) DEFAULT 1.0 COMMENT '灌溉系数',
                frequency_hint VARCHAR(100) COMMENT '频率建议',
                special_notes TEXT COMMENT '特殊注意事项',
                UNIQUE KEY uk_crop_stage (crop_type, stage_name))
                """);
            
            // 5. 创建智能灌溉决策记录表
            createTableIfNotExists("smart_irrigation_decision", """
                (id BIGINT PRIMARY KEY AUTO_INCREMENT,
                point_id BIGINT NOT NULL COMMENT '检测点ID',
                decision_type VARCHAR(20) NOT NULL COMMENT '决策类型',
                predicted_moisture DECIMAL(5,2) COMMENT '预测湿度',
                actual_moisture DECIMAL(5,2) COMMENT '实际湿度',
                prediction_error DECIMAL(5,2) COMMENT '预测误差',
                confidence DECIMAL(5,2) COMMENT '置信度',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_point_time (point_id, created_at))
                """);
            
            // 7. 初始化作物阶段配置数据
            initCropStageConfig();
            
            log.info("智能灌溉表结构初始化完成");
        } catch (Exception e) {
            log.error("智能灌溉表结构初始化失败", e);
        }
    }
    
    private void addColumnIfNotExists(String table, String column, String definition) {
        try {
            jdbcTemplate.queryForObject(
                "SELECT " + column + " FROM " + table + " LIMIT 1", 
                Object.class
            );
            log.debug("列 {}.{} 已存在", table, column);
        } catch (Exception e) {
            try {
                jdbcTemplate.execute(
                    "ALTER TABLE " + table + " ADD COLUMN " + column + " " + definition
                );
                log.info("已添加列 {}.{}", table, column);
            } catch (Exception ex) {
                log.warn("添加列 {}.{} 失败: {}", table, column, ex.getMessage());
            }
        }
    }
    
    private void createTableIfNotExists(String table, String columns) {
        try {
            jdbcTemplate.queryForObject(
                "SELECT 1 FROM " + table + " LIMIT 1", 
                Integer.class
            );
            log.debug("表 {} 已存在", table);
        } catch (Exception e) {
            try {
                jdbcTemplate.execute(
                    "CREATE TABLE " + table + " " + columns + " COMMENT '智能灌溉相关表'"
                );
                log.info("已创建表 {}", table);
            } catch (Exception ex) {
                log.warn("创建表 {} 失败: {}", table, ex.getMessage());
            }
        }
    }
    
    private void initCropStageConfig() {
        // 检查是否已有数据
        Integer count = jdbcTemplate.queryForObject(
            "SELECT COUNT(*) FROM crop_stage_config", Integer.class
        );
        if (count != null && count > 0) {
            return;
        }
        
        // 插入番茄配置
        String[][] tomatoStages = {
            {"tomato", "播种期", "1", "0", "7", "60", "75", "65", "1.2", "每天2-3次少量", "保持表层湿润"},
            {"tomato", "幼苗期", "2", "7", "30", "50", "65", "55", "0.9", "每2天1次", "适度控水促根"},
            {"tomato", "开花期", "3", "30", "50", "40", "55", "48", "0.7", "精准控制", "避免过湿落花"},
            {"tomato", "结果期", "4", "50", "90", "50", "70", "60", "1.1", "每天1-2次", "需水量最大"},
            {"tomato", "成熟期", "5", "90", "120", "40", "55", "48", "0.8", "适当减少", "控水提品质"}
        };
        
        // 插入黄瓜配置
        String[][] cucumberStages = {
            {"cucumber", "播种期", "1", "0", "5", "65", "80", "70", "1.3", "每天多次少量", "喜湿作物"},
            {"cucumber", "幼苗期", "2", "5", "25", "55", "70", "62", "1.0", "每天1次", "需水量较大"},
            {"cucumber", "开花期", "3", "25", "40", "50", "65", "57", "0.8", "适中控制", "避免过湿"},
            {"cucumber", "结果期", "4", "40", "80", "55", "75", "65", "1.2", "每天2次", "需水量大"}
        };
        
        // 插入水稻配置
        String[][] riceStages = {
            {"rice", "播种期", "1", "0", "10", "80", "95", "90", "1.5", "保持水层", "水生作物"},
            {"rice", "分蘖期", "2", "10", "40", "70", "90", "80", "1.2", "浅水层", "促进分蘖"},
            {"rice", "拔节期", "3", "40", "60", "60", "80", "70", "1.0", "干湿交替", "适度晒田"},
            {"rice", "抽穗期", "4", "60", "75", "75", "90", "82", "1.3", "保持水层", "关键需水期"},
            {"rice", "成熟期", "5", "75", "110", "50", "70", "60", "0.7", "逐渐排水", "便于收获"}
        };
        
        String sql = """
            INSERT INTO crop_stage_config 
            (crop_type, stage_name, stage_order, start_day, end_day, 
             min_humidity, max_humidity, optimal_humidity, irrigation_factor, 
             frequency_hint, special_notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """;
        
        for (String[] stage : tomatoStages) {
            jdbcTemplate.update(sql, (Object[]) stage);
        }
        for (String[] stage : cucumberStages) {
            jdbcTemplate.update(sql, (Object[]) stage);
        }
        for (String[] stage : riceStages) {
            jdbcTemplate.update(sql, (Object[]) stage);
        }
        
        log.info("已初始化作物阶段配置数据");
    }
}
