import { Select } from 'antd'
import { useAppStore } from '../stores/appStore'

/** 监测点选择器（全局状态，跨页面共享选中点） */
export default function PointSelector() {
  const points = useAppStore((s) => s.points)
  const pointId = useAppStore((s) => s.pointId)
  const setPointId = useAppStore((s) => s.setPointId)

  if (points.length === 0) return null
  return (
    <Select
      value={pointId}
      onChange={setPointId}
      style={{ minWidth: 160 }}
      options={points.map((p) => ({ value: p.id, label: p.pointName }))}
    />
  )
}
