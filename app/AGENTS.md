# Repository Guidelines

## Project Structure & Module Organization
This repository is a HarmonyOS app in `app/`.
Primary source code is under `entry/src/main/ets/`:
- `pages/`: route-level screens (`Index.ets`, `DevicePage.ets`, `IrrigationPage.ets`)
- `components/`: reusable UI blocks (`DataCard.ets`, `DeviceCard.ets`, `NavBottom.ets`)
- `services/`: API and business logic (`HttpClient.ets`, `SensorService.ets`)
- `models/`: domain models (`Device.ets`, `EnvironmentData.ets`)
- `config/`, `mock/`, `web/`: config constants, mock data, and web assets
Tests are in `entry/src/test/` (for example `List.test.ets`, `LocalUnit.test.ets`).

## Build, Test, and Development Commands
Run commands from repo root (`app/`):
- `hvigorw assembleHap`: builds the installable HAP
- `hvigorw clean`: clears build artifacts
- `hvigorw test`: runs unit tests (Hypium/Hamock)
Use DevEco Studio task runner if CLI tools are not configured locally.

## Coding Style & Naming Conventions
- Language: ArkTS + declarative ArkUI
- Indentation: 2 spaces; keep UI state minimal and explicit
- File and component names: `PascalCase` (`DeviceService.ets`, `@Component struct AlarmCard`)
- Methods/variables: `camelCase`; constants: `UPPER_SNAKE_CASE` or stable `camelCase`
- Decorators: use `@Entry`, `@Component`, `@State`, `@Prop` as intended
Lint config is defined in `code-linter.json5` (`@typescript-eslint`, performance, and security rules).

## Testing Guidelines
- Frameworks: `@ohos/hypium`, `@ohos/hamock`
- Test filename pattern: `*.test.ets`
- Prefer tests for service logic, threshold checks, and key UI state changes
- Execute `hvigorw test` before pushing changes

## Commit & Pull Request Guidelines
Current history uses short, module-focused messages (often Chinese), e.g. `光照`, `灌溉系统`.
Recommended format:
- `模块: 动作/结果` (example: `设备控制: 修复风扇状态同步`)
PRs should include:
- concise change summary and impacted modules
- linked requirement/issue when available
- test evidence (`hvigorw test` result)
- screenshots/video for UI adjustments

## Security & Configuration Tips
Keep gateway endpoints environment-specific in `entry/src/main/ets/services/HttpClient.ets`. Do not commit real internal addresses, tokens, or credentials.
