"""
LSTM土壤湿度预测模型训练脚本
=====================================
功能：训练LSTM模型预测未来土壤湿度变化
输出：ONNX格式模型，可部署到Java后端

训练数据来源（--data-source 可选）：
    real      : 真实土壤湿度数据（默认）。
                通过 Open-Meteo 历史预报存档 API（ECMWF IFS 分析场，
                观测约束下的真实再分析数据，非随机仿真）拉取逐小时
                土壤体积含水量（1-3cm 表层）、气温、相对湿度、短波辐射，
                构造训练数据集并缓存为 CSV（--cache 指定路径）。
    simulated : 真实气象数据驱动的物理仿真。
                从 Open-Meteo 历史气象存档 API 拉取真实逐小时气象数据
                （温度/湿度/短波辐射/降水/风速），用 FAO-56 Penman-Monteith
                蒸散模型推算土壤水分消耗，叠加降水入渗、灌溉事件与传感器噪声，
                构造物理上合理的土壤湿度序列。
    synthetic : 纯随机模拟数据（无网络时的降级方案）。
    csv       : 从CSV文件加载真实传感器数据（--data 指定路径）。

使用方法：
    python train_lstm.py                                    # 真实数据（默认，需联网）
    python train_lstm.py --days 730                         # 拉取最近2年数据
    python train_lstm.py --data-source simulated            # 物理仿真数据
    python train_lstm.py --data-source synthetic            # 纯模拟数据
    python train_lstm.py --data sensor_data.csv --data-source csv
    python train_lstm.py --latitude 32.06 --longitude 118.79 --days 365
"""

import argparse
import json
import os
import urllib.request
from datetime import datetime, timedelta

import matplotlib.pyplot as plt
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import MinMaxScaler
from torch.utils.data import DataLoader, TensorDataset


class MoistureLSTM(nn.Module):
    """
    LSTM模型用于土壤湿度预测

    输入: [batch, seq_len, features]
        - features: [湿度, 温度, 光照, 空气湿度, 小时特征]
    输出: [batch, predict_hours]
        - predict_hours: 未来2/4/6小时的湿度预测
    """

    def __init__(self, input_size=5, hidden_size=64, num_layers=2,
                 output_size=3, dropout=0.2):
        super(MoistureLSTM, self).__init__()

        self.hidden_size = hidden_size
        self.num_layers = num_layers

        # LSTM层
        self.lstm = nn.LSTM(
            input_size=input_size,
            hidden_size=hidden_size,
            num_layers=num_layers,
            batch_first=True,
            dropout=dropout if num_layers > 1 else 0
        )

        # 全连接层
        self.fc1 = nn.Linear(hidden_size, 32)
        self.relu = nn.ReLU()
        self.dropout = nn.Dropout(dropout)
        self.fc2 = nn.Linear(32, output_size)

    def forward(self, x):
        # LSTM
        lstm_out, _ = self.lstm(x)

        # 取最后一个时间步的输出
        out = lstm_out[:, -1, :]

        # 全连接层
        out = self.fc1(out)
        out = self.relu(out)
        out = self.dropout(out)
        out = self.fc2(out)

        return out


class MoisturePredictor:
    """湿度预测器封装类"""

    def __init__(self, seq_length=24, predict_hours=[2, 4, 6]):
        self.seq_length = seq_length
        self.predict_hours = predict_hours
        self.output_size = len(predict_hours)
        self.scaler = MinMaxScaler()
        self.model = None
        self.device = torch.device('cuda' if torch.cuda.is_available() else 'cpu')

    # ------------------------------------------------------------------
    # 数据源一（默认）：真实土壤湿度数据（ECMWF IFS 分析场）
    # ------------------------------------------------------------------

    # 各特征列顺序（全脚本统一）：湿度, 温度, 光照, 空气湿度, 小时/24
    FEATURE_COLUMNS = ['soil_moisture', 'temperature', 'light', 'humidity', 'hour']

    def fetch_real_data(self, latitude=32.06, longitude=118.79, days=730,
                        cache_path='data/soil_moisture_real.csv'):
        """
        拉取真实逐小时土壤湿度与气象数据。

        数据源为 Open-Meteo 历史预报存档 API，其存档的是 ECMWF IFS
        高分辨率模式的分析/预报场——由真实观测同化约束的再分析数据，
        非随机仿真。土壤湿度取 1-3cm 表层体积含水量（m³/m³），
        换算为百分点后与系统内"土壤湿度%"口径一致。

        数据会缓存为 CSV：首次联网拉取后，后续重复训练直接读缓存，
        该 CSV 同时作为项目数据集文件留存备查。

        Args:
            latitude/longitude: 采样点坐标（默认南京附近农田区域）
            days: 回溯天数（默认 730 天 ≈ 2 年，约 1.7 万条逐小时记录）
            cache_path: 缓存 CSV 路径

        Returns:
            data: [n_hours, 5]，列为 [土壤湿度%, 温度, 光照(lux), 空气湿度, 小时/24]
        """
        import pandas as pd

        # 命中缓存则直接使用
        if cache_path and os.path.exists(cache_path):
            print(f"发现数据缓存: {cache_path}，直接加载（删除该文件可重新拉取）")
            df = pd.read_csv(cache_path)
            return df[self.FEATURE_COLUMNS].values

        end_date = datetime.now().date() - timedelta(days=1)
        start_date = end_date - timedelta(days=days)

        url = (
            "https://historical-forecast-api.open-meteo.com/v1/forecast?"
            f"latitude={latitude}&longitude={longitude}"
            f"&start_date={start_date}&end_date={end_date}"
            "&hourly=temperature_2m,relative_humidity_2m,shortwave_radiation,"
            "soil_moisture_1_to_3cm"
            "&timezone=auto"
        )

        print(f"请求真实土壤湿度数据 (ECMWF IFS 分析场): "
              f"{start_date} ~ {end_date} ({latitude}, {longitude})")

        with urllib.request.urlopen(url, timeout=120) as resp:
            payload = json.loads(resp.read().decode('utf-8'))

        if 'hourly' not in payload:
            raise RuntimeError(f"Open-Meteo 返回异常: {payload}")

        hourly = payload['hourly']

        def to_array(key):
            return np.array([np.nan if v is None else v for v in hourly[key]],
                            dtype=np.float64)

        temp = to_array('temperature_2m')
        rh = to_array('relative_humidity_2m')
        radiation = to_array('shortwave_radiation')
        soil_moisture = to_array('soil_moisture_1_to_3cm')
        hour_of_day = np.array(
            [datetime.fromisoformat(t).hour for t in hourly['time']],
            dtype=np.float64)

        # 缺测值线性插值（比填 0 更符合物理连续性）
        def interpolate_nan(arr, name):
            n_missing = int(np.isnan(arr).sum())
            if n_missing == 0:
                return arr
            if n_missing == len(arr):
                raise RuntimeError(f"{name} 全部缺测，请更换采样点坐标")
            idx = np.arange(len(arr))
            valid = ~np.isnan(arr)
            print(f"  {name}: 插值填补 {n_missing} 个缺测值")
            return np.interp(idx, idx[valid], arr[valid])

        temp = interpolate_nan(temp, 'temperature_2m')
        rh = interpolate_nan(rh, 'relative_humidity_2m')
        radiation = interpolate_nan(radiation, 'shortwave_radiation')
        soil_moisture = interpolate_nan(soil_moisture, 'soil_moisture_1_to_3cm')

        # 体积含水量 m³/m³ -> 百分点
        moisture = soil_moisture * 100.0
        # 短波辐射 W/m² -> lux（日光近似换算，与系统历史数据量纲一致）
        light = np.maximum(radiation * 120.0, 0)

        data = np.column_stack([
            moisture,
            temp,
            light,
            np.clip(rh, 0, 100),
            hour_of_day / 24.0,
        ])

        print(f"获取到 {data.shape[0]} 条真实逐小时记录, "
              f"土壤湿度范围 [{moisture.min():.1f}%, {moisture.max():.1f}%]")

        # 缓存为 CSV（含时间戳，便于核查）
        if cache_path:
            os.makedirs(os.path.dirname(cache_path) or '.', exist_ok=True)
            df = pd.DataFrame(data, columns=self.FEATURE_COLUMNS)
            df.insert(0, 'time', hourly['time'])
            df.to_csv(cache_path, index=False)
            print(f"数据已缓存到: {cache_path}")

        return data

    # ------------------------------------------------------------------
    # 数据源二：真实气象数据 + FAO-56 蒸散模型的物理仿真
    # ------------------------------------------------------------------

    def fetch_weather_data(self, latitude=31.23, longitude=121.47, days=180):
        """
        从 Open-Meteo 历史气象存档 API 拉取真实逐小时气象数据。
        免费接口，无需 API Key。默认取上海附近最近 180 天（存档约滞后 5 天）。

        Returns:
            dict，包含 temperature_2m / relative_humidity_2m /
            shortwave_radiation / precipitation / wind_speed_10m / hour_of_day
            六个等长数组
        """
        end_date = datetime.now().date() - timedelta(days=6)
        start_date = end_date - timedelta(days=days)

        url = (
            "https://archive-api.open-meteo.com/v1/archive?"
            f"latitude={latitude}&longitude={longitude}"
            f"&start_date={start_date}&end_date={end_date}"
            "&hourly=temperature_2m,relative_humidity_2m,shortwave_radiation,"
            "precipitation,wind_speed_10m"
            "&timezone=auto"
        )

        print(f"请求 Open-Meteo 历史气象数据: {start_date} ~ {end_date} "
              f"({latitude}, {longitude})")

        with urllib.request.urlopen(url, timeout=60) as resp:
            payload = json.loads(resp.read().decode('utf-8'))

        if 'hourly' not in payload:
            raise RuntimeError(f"Open-Meteo 返回异常: {payload}")

        hourly = payload['hourly']

        def to_array(key):
            # 缺测值填 0
            return np.array([np.nan if v is None else v for v in hourly[key]],
                            dtype=np.float64)

        weather = {
            'temperature_2m': to_array('temperature_2m'),
            'relative_humidity_2m': to_array('relative_humidity_2m'),
            'shortwave_radiation': to_array('shortwave_radiation'),
            'precipitation': to_array('precipitation'),
            'wind_speed_10m': to_array('wind_speed_10m'),
            'hour_of_day': np.array(
                [datetime.fromisoformat(t).hour for t in hourly['time']],
                dtype=np.float64),
        }

        for key in weather:
            weather[key] = np.nan_to_num(weather[key], nan=0.0)

        print(f"获取到 {len(weather['temperature_2m'])} 小时真实气象数据")
        return weather

    @staticmethod
    def _hourly_et0_fao56(temp, rh, radiation, wind10, hour_of_day):
        """
        FAO-56 Penman-Monteith 逐小时参考蒸散量 ET0（mm/h）简化实现。

        Args:
            temp: 气温 (°C)
            rh: 相对湿度 (%)
            radiation: 短波辐射 (W/m²)
            wind10: 10m 风速 (m/s)
            hour_of_day: 小时 (0-23)

        Returns:
            ET0 数组 (mm/h)
        """
        # 饱和水汽压 (kPa)，FAO-56 式
        es = 0.6108 * np.exp(17.27 * temp / (temp + 237.3))
        # 实际水汽压 (kPa)
        ea = es * np.clip(rh, 1, 100) / 100.0
        # 饱和水汽压曲线斜率 (kPa/°C)
        delta = 4098 * es / np.square(temp + 237.3)
        # 干湿表常数 (kPa/°C)，取海拔约 100m
        gamma = 0.067
        # 2m 风速换算
        u2 = np.maximum(wind10, 0.1) * 0.748

        # 净辐射近似：短波辐射 W/m² -> MJ/(m²·h)，夜间取小幅负值
        rs = radiation * 0.0036
        rn = np.where(rs > 0.01, 0.62 * rs, -0.08)
        # 土壤热通量：白天取 0.1Rn，夜间取 0.5Rn
        g = np.where(rs > 0.01, 0.1 * rn, 0.5 * rn)

        # 白天/夜间空气动力系数
        cd = np.where(rs > 0.01, 0.24, 0.96)
        cn = 37.0  # 逐小时尺度系数

        numerator = 0.408 * delta * (rn - g) + \
            gamma * (cn / (temp + 273.0)) * u2 * (es - ea)
        denominator = delta + gamma * (1.0 + cd * u2)

        et0 = numerator / denominator
        return np.maximum(et0, 0.0)

    def generate_physics_simulated_data(self, latitude=31.23, longitude=121.47,
                                        days=180, seed=42):
        """
        物理模型驱动的仿真数据：真实气象数据 + FAO-56 蒸散模型 + 水量平衡。

        土壤湿度按" bucket 水量平衡"演化：
            失水 = 作物蒸散（ET0 × 作物系数）+ 高湿度下的深层渗漏
            补水 = 降水入渗 + 阈值触发的灌溉事件
        最后叠加传感器测量噪声。

        Returns:
            data: [n_hours, 5]，列为 [土壤湿度, 温度, 光照(lux), 空气湿度, 小时/24]
        """
        print("生成物理仿真训练数据（真实气象 + 蒸散模型）...")

        weather = self.fetch_weather_data(latitude, longitude, days)
        rng = np.random.default_rng(seed)

        temp = weather['temperature_2m']
        rh = weather['relative_humidity_2m']
        radiation = weather['shortwave_radiation']
        precip = weather['precipitation']
        wind10 = weather['wind_speed_10m']
        hour_of_day = weather['hour_of_day']

        n = len(temp)
        et0 = self._hourly_et0_fao56(temp, rh, radiation, wind10, hour_of_day)

        kc = 0.9             # 作物系数（设施蔬菜生长期均值）
        irrigation_threshold = 38.0   # 触发灌溉的土壤湿度阈值
        moisture = np.zeros(n)
        m = 55.0             # 初始土壤湿度

        for i in range(n):
            # 蒸散失水：ET0(mm/h) -> 湿度百分点，经验换算系数
            loss = kc * et0[i] * 2.2
            # 深层渗漏：湿度越高，重力排水越快
            drainage = max(0.0, m - 60.0) * 0.02
            # 降水入渗：mm -> 湿度百分点（设施农业按部分入渗计）
            rain_gain = precip[i] * 0.9
            # 灌溉事件：低于阈值大概率触发滴灌
            irrigation = 0.0
            if m < irrigation_threshold and rng.random() < 0.7:
                irrigation = rng.uniform(6.0, 14.0)

            m = m - loss - drainage + rain_gain + irrigation
            m = float(np.clip(m, 20.0, 85.0))
            # 传感器测量噪声
            moisture[i] = m + rng.normal(0, 0.8)

        # 光照：短波辐射 W/m² -> lux（日光近似换算），与历史数据量纲一致
        light = np.maximum(radiation * 120.0 + rng.normal(0, 500, n), 0)

        data = np.column_stack([
            moisture,
            temp,
            light,
            np.clip(rh, 0, 100),
            hour_of_day / 24.0,
        ])

        print(f"仿真数据生成完成: {data.shape[0]} 条逐小时记录, "
              f"湿度范围 [{moisture.min():.1f}, {moisture.max():.1f}]")
        return data

    # ------------------------------------------------------------------
    # 数据源三：纯随机模拟数据（无网络降级方案）
    # ------------------------------------------------------------------

    def generate_synthetic_data(self, n_samples=1000):
        """
        生成模拟数据用于训练（当没有真实数据时）
        模拟土壤湿度的动态变化过程
        """
        print("生成模拟训练数据...")

        np.random.seed(42)

        # 模拟多天的数据（每小时一条）
        total_hours = n_samples + self.seq_length + max(self.predict_hours)

        # 基础参数
        base_moisture = 55.0
        base_temp = 25.0
        base_humidity = 60.0

        data = []

        for hour in range(total_hours):
            # 时间特征
            hour_of_day = hour % 24

            # 温度随时间变化（白天高，夜晚低）
            temp = base_temp + 5 * np.sin(2 * np.pi * hour_of_day / 24) + np.random.normal(0, 2)

            # 空气湿度（与温度负相关）
            air_humidity = base_humidity - 0.5 * temp + np.random.normal(0, 5)
            air_humidity = np.clip(air_humidity, 30, 95)

            # 光照强度（白天有光）
            if 6 <= hour_of_day <= 18:
                light = 20000 + 10000 * np.sin(np.pi * (hour_of_day - 6) / 12) + np.random.normal(0, 2000)
            else:
                light = 100 + np.random.normal(0, 50)
            light = max(0, light)

            # 土壤湿度（受蒸发、温度、灌溉影响）
            # 蒸发速率：温度越高、光照越强、湿度越低，蒸发越快
            evaporation = (temp - 20) * 0.05 + (light / 30000) * 0.1 + (80 - air_humidity) * 0.02

            # 随机灌溉事件
            irrigation = 0
            if np.random.random() < 0.03 and base_moisture < 45:  # 3%概率灌溉
                irrigation = np.random.uniform(5, 15)

            # 更新湿度
            base_moisture = base_moisture - evaporation + irrigation * 1.5
            base_moisture = np.clip(base_moisture, 20, 85)

            # 添加噪声
            moisture = base_moisture + np.random.normal(0, 1)

            data.append([moisture, temp, light, air_humidity, hour_of_day / 24])

        return np.array(data)

    # ------------------------------------------------------------------
    # 序列构造与训练
    # ------------------------------------------------------------------

    def prepare_sequences(self, data):
        """
        准备训练序列数据

        输入: data [n_samples, features]
        输出: X [n_sequences, seq_length, features], y [n_sequences, output_size]
        """
        # 归一化
        data_normalized = self.scaler.fit_transform(data)

        X, y = [], []

        for i in range(len(data) - self.seq_length - max(self.predict_hours)):
            # 输入序列
            X.append(data_normalized[i:i + self.seq_length])

            # 目标：未来2/4/6小时的湿度
            targets = []
            for h in self.predict_hours:
                idx = i + self.seq_length + h
                # 湿度是第0列
                targets.append(data_normalized[idx, 0])
            y.append(targets)

        return np.array(X), np.array(y)

    def train(self, X_train, y_train, X_val, y_val, epochs=100, batch_size=32, lr=0.001):
        """训练模型"""

        # 转换为PyTorch张量
        X_train_tensor = torch.FloatTensor(X_train).to(self.device)
        y_train_tensor = torch.FloatTensor(y_train).to(self.device)
        X_val_tensor = torch.FloatTensor(X_val).to(self.device)
        y_val_tensor = torch.FloatTensor(y_val).to(self.device)

        # 数据加载器
        train_dataset = TensorDataset(X_train_tensor, y_train_tensor)
        train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True)

        # 初始化模型
        self.model = MoistureLSTM(
            input_size=X_train.shape[2],
            hidden_size=64,
            num_layers=2,
            output_size=self.output_size
        ).to(self.device)

        # 损失函数和优化器
        criterion = nn.MSELoss()
        optimizer = optim.Adam(self.model.parameters(), lr=lr)
        scheduler = optim.lr_scheduler.ReduceLROnPlateau(optimizer, patience=10, factor=0.5)

        # 训练循环
        train_losses = []
        val_losses = []
        best_val_loss = float('inf')

        print(f"\n开始训练 (设备: {self.device})...")
        print("-" * 60)

        for epoch in range(epochs):
            # 训练阶段
            self.model.train()
            train_loss = 0.0

            for batch_X, batch_y in train_loader:
                optimizer.zero_grad()
                outputs = self.model(batch_X)
                loss = criterion(outputs, batch_y)
                loss.backward()
                torch.nn.utils.clip_grad_norm_(self.model.parameters(), 1.0)
                optimizer.step()
                train_loss += loss.item()

            train_loss /= len(train_loader)
            train_losses.append(train_loss)

            # 验证阶段
            self.model.eval()
            with torch.no_grad():
                val_outputs = self.model(X_val_tensor)
                val_loss = criterion(val_outputs, y_val_tensor).item()
                val_losses.append(val_loss)

            # 学习率调度
            scheduler.step(val_loss)

            # 保存最佳模型
            if val_loss < best_val_loss:
                best_val_loss = val_loss
                best_model_state = self.model.state_dict().copy()

            # 打印进度
            if (epoch + 1) % 10 == 0:
                print(f"Epoch [{epoch+1}/{epochs}] "
                      f"Train Loss: {train_loss:.6f} "
                      f"Val Loss: {val_loss:.6f} "
                      f"LR: {optimizer.param_groups[0]['lr']:.6f}")

        # 恢复最佳模型
        self.model.load_state_dict(best_model_state)
        print("-" * 60)
        print(f"训练完成! 最佳验证损失: {best_val_loss:.6f}")

        return train_losses, val_losses

    # ------------------------------------------------------------------
    # 评估：真实湿度单位下的 MAE
    # ------------------------------------------------------------------

    def evaluate_mae(self, X_test, y_test):
        """
        在测试集上计算 MAE，并将归一化值还原为真实湿度（百分点）后再计算，
        使结果具有明确的物理意义（单位：湿度百分点）。

        Returns:
            mae_per_horizon: 各预测时长（2h/4h/6h）的 MAE
            mae_overall: 整体 MAE
        """
        if self.model is None:
            raise ValueError("模型未训练")

        self.model.eval()
        X_tensor = torch.FloatTensor(X_test).to(self.device)

        with torch.no_grad():
            preds = self.model(X_tensor).cpu().numpy()

        # 反归一化（湿度为第 0 列）
        moisture_min = self.scaler.data_min_[0]
        moisture_max = self.scaler.data_max_[0]
        scale = moisture_max - moisture_min

        preds_real = preds * scale + moisture_min
        y_real = y_test * scale + moisture_min

        mae_per_horizon = np.mean(np.abs(preds_real - y_real), axis=0)
        mae_overall = float(np.mean(np.abs(preds_real - y_real)))

        return mae_per_horizon, mae_overall

    def print_mae_report(self, mae_per_horizon, mae_overall):
        """打印 MAE 评估报告"""
        print("\n" + "=" * 60)
        print("测试集 MAE 评估（单位：湿度百分点）")
        print("=" * 60)
        for h, mae in zip(self.predict_hours, mae_per_horizon):
            print(f"  未来 {h}h 预测 MAE: {mae:.2f}")
        print(f"  整体 MAE:          {mae_overall:.2f}")
        print("=" * 60)

    # ------------------------------------------------------------------
    # 导出与推理
    # ------------------------------------------------------------------

    def export_to_onnx(self, save_path):
        """导出为ONNX格式"""
        if self.model is None:
            raise ValueError("模型未训练，请先调用train方法")

        self.model.eval()

        # 创建示例输入
        dummy_input = torch.randn(1, self.seq_length, 5).to(self.device)

        # 导出ONNX
        torch.onnx.export(
            self.model,
            dummy_input,
            save_path,
            input_names=['input'],
            output_names=['output'],
            dynamic_axes={
                'input': {0: 'batch_size'},
                'output': {0: 'batch_size'}
            },
            opset_version=11
        )

        print(f"模型已导出到: {save_path}")

        # 验证导出
        self.verify_onnx_model(save_path, dummy_input)

    def verify_onnx_model(self, onnx_path, test_input):
        """验证ONNX模型"""
        try:
            import onnxruntime as ort

            # ONNX推理
            ort_session = ort.InferenceSession(onnx_path)
            ort_inputs = {ort_session.get_inputs()[0].name: test_input.cpu().numpy()}
            ort_outputs = ort_session.run(None, ort_inputs)[0]

            # PyTorch推理
            with torch.no_grad():
                torch_output = self.model(test_input).cpu().numpy()

            # 比较
            diff = np.abs(ort_outputs - torch_output).max()
            print(f"ONNX验证通过! 最大差异: {diff:.8f}")

        except ImportError:
            print("onnxruntime未安装，跳过验证")

    def predict(self, sequence):
        """
        使用训练好的模型进行预测

        Args:
            sequence: [seq_length, features] 或 [batch, seq_length, features]

        Returns:
            预测的湿度值 [batch, output_size]
        """
        if self.model is None:
            raise ValueError("模型未训练")

        self.model.eval()

        # 确保输入形状正确
        if len(sequence.shape) == 2:
            sequence = sequence[np.newaxis, :]

        # 归一化
        sequence_normalized = self.scaler.transform(sequence.reshape(-1, 5)).reshape(sequence.shape)

        # 转换为张量
        x = torch.FloatTensor(sequence_normalized).to(self.device)

        # 预测
        with torch.no_grad():
            output = self.model(x)

        # 反归一化（仅湿度）
        result = output.cpu().numpy()

        # 将归一化值转换回实际湿度
        moisture_min = self.scaler.data_min_[0]
        moisture_max = self.scaler.data_max_[0]

        return result * (moisture_max - moisture_min) + moisture_min

    def plot_training_history(self, train_losses, val_losses, save_path=None):
        """绘制训练曲线"""
        plt.figure(figsize=(10, 6))
        plt.plot(train_losses, label='训练损失')
        plt.plot(val_losses, label='验证损失')
        plt.xlabel('Epoch')
        plt.ylabel('Loss (MSE)')
        plt.title('训练过程')
        plt.legend()
        plt.grid(True)

        if save_path:
            plt.savefig(save_path, dpi=150, bbox_inches='tight')
            print(f"训练曲线已保存到: {save_path}")

        plt.close()


def main():
    parser = argparse.ArgumentParser(description='训练LSTM土壤湿度预测模型')
    parser.add_argument('--epochs', type=int, default=100, help='训练轮数')
    parser.add_argument('--batch-size', type=int, default=32, help='批次大小')
    parser.add_argument('--lr', type=float, default=0.001, help='学习率')
    parser.add_argument('--output', type=str, default='moisture_lstm.onnx', help='输出模型路径')
    parser.add_argument('--data', type=str, default=None, help='训练数据CSV路径（可选）')
    parser.add_argument('--data-source', type=str, default='real',
                        choices=['real', 'simulated', 'synthetic', 'csv'],
                        help='数据来源: real=真实土壤湿度(ECMWF分析场,默认), '
                             'simulated=真实气象+蒸散模型仿真, '
                             'synthetic=纯随机模拟, csv=真实传感器CSV')
    parser.add_argument('--cache', type=str, default='data/soil_moisture_real.csv',
                        help='真实数据的本地缓存CSV路径')
    parser.add_argument('--latitude', type=float, default=32.06, help='采样点纬度')
    parser.add_argument('--longitude', type=float, default=118.79, help='采样点经度')
    parser.add_argument('--days', type=int, default=730, help='回溯数据的天数')
    args = parser.parse_args()

    print("=" * 60)
    print("LSTM 土壤湿度预测模型训练")
    print("=" * 60)

    # 初始化预测器
    predictor = MoisturePredictor(seq_length=24, predict_hours=[2, 4, 6])

    # 加载或生成数据
    if args.data_source == 'csv' and args.data and os.path.exists(args.data):
        print(f"从文件加载数据: {args.data}")
        import pandas as pd
        df = pd.read_csv(args.data)
        # 假设CSV列: soil_moisture, temperature, light, humidity, hour
        data = df[['soil_moisture', 'temperature', 'light', 'humidity', 'hour']].values
    elif args.data_source == 'real':
        try:
            data = predictor.fetch_real_data(
                latitude=args.latitude,
                longitude=args.longitude,
                days=args.days,
                cache_path=args.cache,
            )
        except Exception as e:
            raise SystemExit(
                f"真实数据获取失败: {e}\n"
                "请检查网络后重试；若该坐标土壤湿度缺测，请用 "
                "--latitude/--longitude 更换为内陆农田区域采样点。\n"
                "（不建议自动降级为模拟数据——那会让 MAE 指标失去真实性。"
                "如确需降级，请显式使用 --data-source simulated 或 synthetic）"
            )
    elif args.data_source == 'simulated':
        try:
            data = predictor.generate_physics_simulated_data(
                latitude=args.latitude,
                longitude=args.longitude,
                days=args.days,
            )
        except Exception as e:
            print(f"气象数据获取失败 ({e})，降级为纯模拟数据")
            data = predictor.generate_synthetic_data(n_samples=5000)
    else:
        data = predictor.generate_synthetic_data(n_samples=5000)

    print(f"数据形状: {data.shape}")

    # 准备序列数据
    X, y = predictor.prepare_sequences(data)
    print(f"序列数据: X={X.shape}, y={y.shape}")

    # 按时间顺序划分：70% 训练 / 15% 验证 / 15% 测试
    # （时序数据不打乱，测试集取最后一段，模拟"用历史预测未来"的真实场景）
    X_train, X_temp, y_train, y_temp = train_test_split(
        X, y, test_size=0.3, shuffle=False)
    X_val, X_test, y_val, y_test = train_test_split(
        X_temp, y_temp, test_size=0.5, shuffle=False)
    print(f"训练集: {X_train.shape}, 验证集: {X_val.shape}, 测试集: {X_test.shape}")

    # 训练模型
    train_losses, val_losses = predictor.train(
        X_train, y_train, X_val, y_val,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr
    )

    # 在测试集上评估 MAE（真实湿度单位）
    mae_per_horizon, mae_overall = predictor.evaluate_mae(X_test, y_test)
    predictor.print_mae_report(mae_per_horizon, mae_overall)

    # 绘制训练曲线
    predictor.plot_training_history(
        train_losses, val_losses,
        save_path=args.output.replace('.onnx', '_training.png')
    )

    # 导出ONNX模型
    predictor.export_to_onnx(args.output)

    # 测试预测
    print("\n测试预测...")
    test_sequence = X_test[0:1]  # 取一个测试样本
    prediction = predictor.predict(test_sequence[0])
    print(f"预测未来2/4/6小时湿度: {prediction[0]}")

    print("\n" + "=" * 60)
    print("训练完成!")
    print(f"模型文件: {args.output}")
    print("=" * 60)


if __name__ == '__main__':
    main()
