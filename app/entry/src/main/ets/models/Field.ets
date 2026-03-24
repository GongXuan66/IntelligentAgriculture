/**
 * 地块数据模型（兼容层）
 * 注：推荐使用 Farm 模型
 * 此文件保留用于向后兼容
 */

// 重导出 Farm 模型
export { 
  Farm as Field, 
  MonitorPoint, 
  FarmType as FieldType, 
  FarmTypeNames as FieldTypeNames,
  CropPlanting,
  CropStageConfig,
  CropType
} from './Farm'

/**
 * 兼容旧版的字段映射说明：
 * - Field.fieldId → Farm.farmId
 * - Field.fieldName → Farm.farmName
 * - Field.fieldType → Farm.farmType
 * - FieldTypeNames['greenhouse'] → FarmTypeNames['greenhouse']
 */