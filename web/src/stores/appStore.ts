import { create } from 'zustand'
import { persist } from 'zustand/middleware'
import { getMonitorPoints } from '../api/business'
import type { MonitorPoint } from '../api/types'

interface AppState {
  /** 全局选中的监测点 ID（跨看板/灌溉页共享，localStorage 持久化） */
  pointId: number
  points: MonitorPoint[]
  setPointId: (id: number) => void
  loadPoints: () => Promise<void>
}

export const useAppStore = create<AppState>()(
  persist(
    (set, get) => ({
      pointId: 1,
      points: [],
      setPointId: (id) => set({ pointId: id }),
      loadPoints: async () => {
        try {
          const list = await getMonitorPoints()
          set({ points: list })
          // 持久化的 pointId 已不在列表中时回退到第一个点
          if (list.length > 0 && !list.some((p) => p.id === get().pointId)) {
            set({ pointId: list[0].id })
          }
        } catch {
          /* IA-server 未启动时静默，页面显示空态 */
        }
      },
    }),
    {
      name: 'ia-web-app',
      partialize: (s) => ({ pointId: s.pointId }),
    },
  ),
)
