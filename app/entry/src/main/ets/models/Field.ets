/**
 * 地块数据模型
 */
export class Field {
  id?: number                    // ID
  fieldId?: string               // 地块编号
  fieldName: string = ''         // 地块名称
  fieldType?: string             // 类型: greenhouse/outdoor/orchard
  location?: string              // 位置描述
  area?: number                  // 面积(亩)
  cropType?: string              // 主要作物
  description?: string           // 描述
  status?: number                // 状态: 0停用 1启用
  pointCount?: number            // 检测点数量
  createdAt?: string             // 创建时间
  updatedAt?: string             // 更新时间
}

/**
 * 检测点模型（扩展）
 */
export class MonitorPoint {
  id?: number                    // ID
  fieldId?: number               // 所属地块ID
  pointId?: string               // 检测点编号
  pointName: string = ''         // 检测点名称
  location?: string              // 位置
  cropType?: string              // 作物类型
  status?: number                // 状态
  fieldName?: string             // 关联的地块名称
  createdAt?: string
  updatedAt?: string
}

/**
 * 地块类型枚举
 */
export enum FieldType {
  GREENHOUSE = 'greenhouse',     // 大棚
  OUTDOOR = 'outdoor',           // 户外
  ORCHARD = 'orchard',           // 果园
  OTHER = 'other'                // 其他
}

/**
 * 地块类型显示名称映射
 */
export const FieldTypeNames: Record<string, string> = {
  'greenhouse': '大棚',
  'outdoor': '户外田地',
  'orchard': '果园',
  'other': '其他'
}
