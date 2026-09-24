import { useMemo } from 'react'

interface Point {
  label: string
  value: number
}

interface Props {
  points: Point[]
  height?: number
  color?: string
  unit?: string
}

/** 轻量 SVG 折线图（零依赖），用于环境历史与湿度预测曲线 */
export default function TrendChart({ points, height = 160, color = '#52c41a', unit = '' }: Props) {
  const { path, circles, yMin, yMax } = useMemo(() => {
    if (points.length === 0) {
      return { path: '', circles: [] as { x: number; y: number }[], yMin: 0, yMax: 0 }
    }
    // viewBox 坐标系：100 x 50
    const w = 100
    const h = 50
    const pad = 8
    const values = points.map((p) => p.value)
    const min = Math.min(...values)
    const max = Math.max(...values)
    const span = max - min || 1
    const step = points.length > 1 ? (w - pad * 2) / (points.length - 1) : 0

    const coords = points.map((p, i) => ({
      x: pad + step * i,
      y: pad + (1 - (p.value - min) / span) * (h - pad * 2),
    }))
    const d = coords.map((c, i) => `${i === 0 ? 'M' : 'L'}${c.x},${c.y}`).join(' ')
    return { path: d, circles: coords, yMin: min, yMax: max }
  }, [points])

  if (points.length === 0) return null

  return (
    <div>
      <svg
        viewBox="0 0 100 50"
        preserveAspectRatio="none"
        style={{ width: '100%', height, display: 'block' }}
      >
        <path
          d={path}
          fill="none"
          stroke={color}
          strokeWidth={1.5}
          vectorEffect="non-scaling-stroke"
        />
        {circles.map((c, i) => (
          <circle key={i} cx={c.x} cy={c.y} r={1.2} fill={color} />
        ))}
      </svg>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          fontSize: 12,
          color: '#999',
        }}
      >
        <span>
          {points[0].label}（{points[0].value}
          {unit}）
        </span>
        <span>
          范围 {yMin}~{yMax}
          {unit}
        </span>
        <span>
          {points[points.length - 1].label}（{points[points.length - 1].value}
          {unit}）
        </span>
      </div>
    </div>
  )
}
