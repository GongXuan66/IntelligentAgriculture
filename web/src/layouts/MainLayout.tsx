import { useEffect, useState } from 'react'
import { Layout, Menu, Badge } from 'antd'
import {
  RobotOutlined,
  DashboardOutlined,
  ControlOutlined,
  CloudOutlined,
  AlertOutlined,
} from '@ant-design/icons'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { getUnprocessedAlarmCount } from '../api/business'

const { Sider, Header, Content } = Layout

export default function MainLayout() {
  const navigate = useNavigate()
  const location = useLocation()
  const [alarmCount, setAlarmCount] = useState(0)

  useEffect(() => {
    let mounted = true
    const load = () =>
      getUnprocessedAlarmCount()
        .then((n) => mounted && setAlarmCount(Number(n) || 0))
        .catch(() => {})
    load()
    const timer = setInterval(load, 30_000)
    return () => {
      mounted = false
      clearInterval(timer)
    }
  }, [location.pathname])

  const selected = location.pathname === '/' ? '/' : location.pathname

  return (
    <Layout style={{ height: '100vh' }}>
      <Sider theme="light" width={208}>
        <div
          style={{
            height: 56,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontWeight: 700,
            fontSize: 16,
            color: '#2f5e2f',
          }}
        >
          🌱 智慧农业
        </div>
        <Menu
          mode="inline"
          selectedKeys={[selected]}
          onClick={({ key }) => navigate(key)}
          items={[
            { key: '/', icon: <RobotOutlined />, label: 'AI 助手' },
            { key: '/dashboard', icon: <DashboardOutlined />, label: '数据看板' },
            { key: '/devices', icon: <ControlOutlined />, label: '设备管理' },
            { key: '/irrigation', icon: <CloudOutlined />, label: '智能灌溉' },
            {
              key: '/alarms',
              icon: <AlertOutlined />,
              label: (
                <Badge count={alarmCount} size="small" offset={[8, 0]}>
                  告警中心
                </Badge>
              ),
            },
          ]}
        />
      </Sider>
      <Layout>
        <Header
          style={{
            background: '#fff',
            padding: '0 24px',
            height: 56,
            lineHeight: '56px',
            borderBottom: '1px solid #eee',
            fontWeight: 600,
          }}
        >
          智慧农业管理平台
        </Header>
        <Content style={{ overflow: 'auto', padding: 16 }}>
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  )
}
