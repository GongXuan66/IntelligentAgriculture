import { AppConfig } from '../config/AppConfig'
import { MockDataManager } from './MockDataManager'

export class IrrigationCommand {
  pointId: number = 1
  durationSeconds: number = 0
  mode: number = 1
}

export class LightAdjustCommand {
  pointId: number = 1
  brightness: number = 0
  targetLight: number = 300
}

export class VentilationAdjustCommand {
  pointId: number = 1
  fanLevel: number = 0
  targetTemperature: number = 30
  targetCo2: number = 1000
}

/**
 * 环境控制端口
 * 说明:
 * - 当前用模拟实现驱动数据库更新
 * - 未来接入真实传感器/控制器时，仅替换实现类
 */
export interface EnvironmentControlPort {
  onIrrigationCompleted(command: IrrigationCommand): Promise<void>
  onLightAdjusted(command: LightAdjustCommand): Promise<void>
  onVentilationAdjusted(command: VentilationAdjustCommand): Promise<void>
}

/**
 * 网关控制端口（当前实现）
 */
export class GatewayEnvironmentControlPort implements EnvironmentControlPort {
  private readonly appConfig: AppConfig = AppConfig.getInstance()
  private readonly mockManager: MockDataManager = MockDataManager.getInstance()

  async onIrrigationCompleted(command: IrrigationCommand): Promise<void> {
    if (!this.appConfig.simulationMode) {
      return
    }
    await this.mockManager.applyIrrigationEffect(command.durationSeconds, command.pointId)
  }

  async onLightAdjusted(command: LightAdjustCommand): Promise<void> {
    if (!this.appConfig.simulationMode) {
      return
    }
    await this.mockManager.applyLightControlEffect(
      command.brightness,
      command.targetLight,
      command.pointId
    )
  }

  async onVentilationAdjusted(command: VentilationAdjustCommand): Promise<void> {
    if (!this.appConfig.simulationMode) {
      return
    }
    await this.mockManager.applyVentilationEffect(
      command.fanLevel,
      command.targetTemperature,
      command.targetCo2,
      command.pointId
    )
  }
}
