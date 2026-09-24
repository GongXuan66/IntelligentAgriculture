# LSTM 土壤湿度预测模型训练

在**带独显的机器**上运行本目录的训练脚本（开发机未安装 torch 等依赖）。

## 训练数据

默认数据源（`--data-source real`）为**真实土壤湿度数据**：通过 Open-Meteo
历史预报存档 API 获取 ECMWF IFS 高分辨率模式分析场（真实观测同化约束的
再分析数据，非随机仿真），包含逐小时：

- 1–3cm 表层土壤体积含水量（m³/m³，脚本换算为百分点）
- 2m 气温、2m 相对湿度、短波辐射（换算为光照 lux）

首次运行会自动联网拉取并缓存为 `data/soil_moisture_real.csv`（约 1.7 万条
逐小时记录，该 CSV 即项目数据集文件，可留存备查）；后续训练直接读缓存，
删除缓存文件即可重新拉取。

## 运行步骤

```bash
cd ml-models

# 1. 建议创建虚拟环境
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# 2. 安装依赖（GPU 版 torch 安装命令见 requirements.txt 注释）
pip install -r requirements.txt

# 3. 训练（默认拉取最近 730 天真实数据，输出到 ml-models/moisture_lstm.onnx）
python train_lstm.py

# 常用参数
python train_lstm.py --days 365                    # 只取最近 1 年
python train_lstm.py --latitude 31.23 --longitude 121.47   # 换采样点（沿海点土壤湿度可能缺测，建议选内陆农田区域）
python train_lstm.py --epochs 150 --batch-size 64  # 调训练超参
```

## 输出产物

| 文件 | 说明 |
| --- | --- |
| `moisture_lstm.onnx` | 训练好的模型，Java 后端 `ONNXPredictor` 默认从 `ml-models/moisture_lstm.onnx` 加载，无需移动 |
| `moisture_lstm_training.png` | 训练/验证损失曲线 |
| 终端 MAE 报告 | 测试集上未来 2h/4h/6h 及整体 MAE（单位：湿度百分点），**简历中的精度指标以本次实测数字为准** |
| `data/soil_moisture_real.csv` | 真实数据集缓存 |

## 其他数据源（备用）

```bash
python train_lstm.py --data-source simulated   # 真实气象 + FAO-56 蒸散模型物理仿真
python train_lstm.py --data-source synthetic   # 纯随机模拟（无网络降级）
python train_lstm.py --data-source csv --data your.csv   # 自有传感器 CSV
```

自有 CSV 需包含列：`soil_moisture, temperature, light, humidity, hour`。

## 完成后

训练结束把终端里的 MAE 报告数字带回来，据此更新简历中的
"预测误差 MAE 控制在 X 以内"表述（X 必须等于实测值）。
