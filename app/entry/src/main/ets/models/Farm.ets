/**
 * 农场数据模型
 * 注：由 Field 重命名为 Farm，支持多租户架构
 */
export class Farm {
  id?: number                    // ID
  userId?: number                // 所属用户ID
  farmId?: string                // 农场编号（兼容旧版 fieldId）
  farmCode?: string              // 农场编码
  farmName: string = ''          // 农场名称
  farmType?: string              // 类型: greenhouse/outdoor/orchard（兼容旧版 fieldType）
  location?: string              // 地址
  province?: string              // 省份
  city?: string                  // 城市
  area?: number                  // 面积(亩)
  cropType?: string              // 主要作物
  description?: string           // 描述
  status?: number                // 状态: 0停用 1启用
  pointCount?: number            // 检测点数量
  createdAt?: string             // 创建时间
  updatedAt?: string             // 更新时间
}

/**
 * 检测点/地块模型
 */
export class MonitorPoint {
  id?: number                    // ID
  farmId?: number                // 所属农场ID
  pointCode?: string             // 检测点编码
  pointName: string = ''         // 检测点名称
  location?: string              // 位置描述
  area?: number                  // 面积(亩)
  soilType?: string              // 土壤类型: sandy/clay/loam
  status?: number                // 状态: 0停用 1启用
  farmName?: string              // 关联的农场名称
  createdAt?: string
  updatedAt?: string
}

/**
 * 土壤类型枚举
 */
export enum SoilType {
  SANDY = 'sandy',       // 沙土
  CLAY = 'clay',         // 粘土
  LOAM = 'loam',         // 壤土
  OTHER = 'other'        // 其他
}

/**
 * 土壤类型显示名称映射
 */
export const SoilTypeNames: Record<string, string> = {
  'sandy': '沙土',
  'clay': '粘土',
  'loam': '壤土',
  'other': '其他'
}

/**
 * 作物种植信息
 */
export class CropPlanting {
  id?: number
  pointId?: number
  cropCode?: string              // 作物编码
  cropName?: string              // 作物名称
  variety?: string               // 品种
  plantingDate?: string          // 播种日期
  expectedHarvestDate?: string   // 预计收获日期
  currentStage?: string          // 当前生长阶段
  currentStageDay?: number       // 当前阶段天数
  status?: number                // 状态: 0已收获 1生长中
}

/**
 * 作物生长阶段配置
 */
export class CropStageConfig {
  id?: number
  cropCode?: string
  stageCode?: string
  stageName?: string
  stageOrder?: number
  startDay?: number
  endDay?: number
  minHumidity?: number
  maxHumidity?: number
  optimalHumidity?: number
  irrigationFactor?: number
  frequencyHint?: string
  waterNeeds?: string
  specialNotes?: string
}

/**
 * 作物类型
 */
export class CropType {
  cropCode?: string
  cropName?: string
  category?: string              // 分类: vegetable/fruit/grain
  growthCycleDays?: number       // 生长周期(天)
  waterRequirement?: string      // 需水特性: low/medium/high
  temperatureRange?: string      // 适宜温度范围
  description?: string
  isActive?: number
}

/**
 * 农场类型枚举（兼容旧版 FieldType）
 */
export enum FarmType {
  GREENHOUSE = 'greenhouse',     // 大棚
  OUTDOOR = 'outdoor',           // 户外
  ORCHARD = 'orchard',           // 果园
  OTHER = 'other'                // 其他
}

/**
 * 农场类型显示名称映射（兼容旧版 FieldTypeNames）
 */
export const FarmTypeNames: Record<string, string> = {
  'greenhouse': '大棚',
  'outdoor': '户外田地',
  'orchard': '果园',
  'other': '其他'
}
