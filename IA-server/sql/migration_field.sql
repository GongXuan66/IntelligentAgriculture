-- =====================================================
-- 数据库迁移：新增地块（Field）层级
-- 执行时间：2026-03-19
-- 说明：在检测点之上增加地块层级，支持多田地管理
-- =====================================================

USE agriculture;

-- =====================================================
-- 1. 新增地块表
-- =====================================================
CREATE TABLE IF NOT EXISTS field (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    field_id VARCHAR(50) NOT NULL UNIQUE COMMENT '地块编号',
    field_name VARCHAR(100) NOT NULL COMMENT '地块名称',
    field_type VARCHAR(20) DEFAULT 'outdoor' COMMENT '类型: greenhouse大棚/outdoor户外/orchard果园/other其他',
    location VARCHAR(200) COMMENT '位置描述',
    area DECIMAL(10,2) COMMENT '面积(亩)',
    crop_type VARCHAR(50) COMMENT '主要作物',
    description VARCHAR(500) COMMENT '描述',
    status TINYINT DEFAULT 1 COMMENT '状态: 0停用 1启用',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_status (status),
    INDEX idx_field_type (field_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='地块表';

-- =====================================================
-- 2. 修改检测点表，增加地块关联
-- =====================================================
ALTER TABLE monitor_point 
ADD COLUMN field_id BIGINT COMMENT '所属地块ID' AFTER id;

ALTER TABLE monitor_point 
ADD INDEX idx_field_id (field_id);

-- =====================================================
-- 3. 插入默认地块数据
-- =====================================================
INSERT INTO field (field_id, field_name, field_type, location, area, crop_type, description) VALUES
('F001', '1号田', 'outdoor', '东区', 5.0, '水稻', '主要水稻种植区'),
('F002', '2号大棚', 'greenhouse', '西区', 2.0, '番茄', '温室番茄种植');

-- =====================================================
-- 4. 更新现有检测点，关联到默认地块
-- =====================================================
-- 将现有检测点关联到1号田
UPDATE monitor_point SET field_id = 1 WHERE field_id IS NULL;

-- =====================================================
-- 5. 插入测试检测点数据
-- =====================================================
INSERT INTO monitor_point (field_id, point_id, point_name, location, crop_type, status) VALUES
(1, 'P001-A', 'A区', '1号田东侧', '水稻', 1),
(1, 'P001-B', 'B区', '1号田西侧', '水稻', 1),
(2, 'P002-A', 'A区', '2号大棚北侧', '番茄', 1),
(2, 'P002-B', 'B区', '2号大棚南侧', '番茄', 1);

-- =====================================================
-- 6. 更新设备数据关联到新检测点
-- =====================================================
-- 如果需要，可以将设备重新分配到不同检测点

-- =====================================================
-- 7. 验证迁移结果
-- =====================================================
-- SELECT f.field_name, p.point_name, d.device_name 
-- FROM field f 
-- LEFT JOIN monitor_point p ON f.id = p.field_id 
-- LEFT JOIN device d ON p.id = d.point_id;
