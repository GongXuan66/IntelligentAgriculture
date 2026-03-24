"""
LSTM土壤湿度预测模型训练脚本
=====================================
功能：训练LSTM模型预测未来土壤湿度变化
输出：ONNX格式模型，可部署到Java后端

使用方法：
    python train_lstm.py --epochs 100 --data sensor_data.csv
    python train_lstm.py  # 使用模拟数据
"""

import argparse
import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader, TensorDataset
from sklearn.preprocessing import MinMaxScaler
from sklearn.model_selection import train_test_split
import matplotlib.pyplot as plt
import os
from datetime import datetime


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
                # 湿度是第0列，反归一化后再归一化
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
    args = parser.parse_args()
    
    print("=" * 60)
    print("LSTM 土壤湿度预测模型训练")
    print("=" * 60)
    
    # 初始化预测器
    predictor = MoisturePredictor(seq_length=24, predict_hours=[2, 4, 6])
    
    # 加载或生成数据
    if args.data and os.path.exists(args.data):
        print(f"从文件加载数据: {args.data}")
        import pandas as pd
        df = pd.read_csv(args.data)
        # 假设CSV列: moisture, temperature, light, humidity, hour
        data = df[['soil_moisture', 'temperature', 'light', 'humidity', 'hour']].values
    else:
        data = predictor.generate_synthetic_data(n_samples=5000)
    
    print(f"数据形状: {data.shape}")
    
    # 准备序列数据
    X, y = predictor.prepare_sequences(data)
    print(f"序列数据: X={X.shape}, y={y.shape}")
    
    # 划分训练集和验证集
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, shuffle=False)
    print(f"训练集: {X_train.shape}, 验证集: {X_val.shape}")
    
    # 训练模型
    train_losses, val_losses = predictor.train(
        X_train, y_train, X_val, y_val,
        epochs=args.epochs,
        batch_size=args.batch_size,
        lr=args.lr
    )
    
    # 绘制训练曲线
    predictor.plot_training_history(
        train_losses, val_losses,
        save_path=args.output.replace('.onnx', '_training.png')
    )
    
    # 导出ONNX模型
    predictor.export_to_onnx(args.output)
    
    # 测试预测
    print("\n测试预测...")
    test_sequence = X_val[0:1]  # 取一个验证样本
    prediction = predictor.predict(test_sequence[0])
    print(f"预测未来2/4/6小时湿度: {prediction[0]}")
    
    print("\n" + "=" * 60)
    print("训练完成!")
    print(f"模型文件: {args.output}")
    print("=" * 60)


if __name__ == '__main__':
    main()

