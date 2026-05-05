from langchain_core.tools import tool
from app.services.http_client import java_client
import json


@tool(description="预测未来土壤湿度。基于机器学习模型预测指定时间后的土壤水分含量。")
async def predict_moisture(point_id: int = 1, hours_ahead: int = 4) -> str:
    """预测未来土壤湿度"""
    try:
        result = await java_client.predict_moisture(
            point_id=point_id,
            hours_ahead=hours_ahead
        )
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"预测失败: {str(e)}"


@tool(description="分析土壤湿度预测结果，判断是否需要灌溉。")
async def analyze_moisture_prediction(point_id: int = 1, threshold: float = 40) -> str:
    """分析预测结果"""
    try:
        result = await java_client.analyze_moisture_prediction(
            point_id=point_id,
            threshold=threshold
        )
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"分析失败: {str(e)}"


@tool(description="查看智能灌溉的学习进度，了解模型已训练的程度。")
async def get_learning_progress(point_id: int = 1) -> str:
    """查看学习进度"""
    try:
        result = await java_client.get_learning_progress(point_id=point_id)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取学习进度失败: {str(e)}"


@tool(description="查看已学习的灌溉参数，包括土壤特性和作物需水模型。")
async def get_learned_params(point_id: int = 1) -> str:
    """查看学习参数"""
    try:
        result = await java_client.get_learned_params(point_id=point_id)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取学习参数失败: {str(e)}"


@tool(description="获取当前使用的灌溉策略，包括触发阈值、灌溉量等。")
async def get_irrigation_strategy(point_id: int = 1) -> str:
    """获取灌溉策略"""
    try:
        result = await java_client.get_irrigation_strategy(point_id=point_id)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取灌溉策略失败: {str(e)}"


@tool(description="设置作物信息，包括作物类型和种植日期，以便系统优化灌溉。")
async def set_crop_info(point_id: int, crop_code: str, planting_date: str) -> str:
    """设置作物信息"""
    try:
        payload = {
            "cropCode": crop_code,
            "plantingDate": planting_date
        }
        result = await java_client.set_crop_info(payload=payload, point_id=point_id)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"设置作物信息失败: {str(e)}"


@tool(description="获取指定作物类型的生长阶段配置。")
async def get_crop_stage_configs(crop_type: str) -> str:
    """获取作物生长阶段配置"""
    try:
        result = await java_client.get_crop_stage_configs(crop_type=crop_type)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取生长阶段配置失败: {str(e)}"


@tool(description="获取系统支持的作物类型列表。")
async def get_supported_crop_types() -> str:
    """获取支持的作物类型"""
    try:
        result = await java_client.get_supported_crop_types()
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取作物类型失败: {str(e)}"


@tool(description="获取智能灌溉统计信息，包括总灌溉次数、节约水量等。")
async def get_smart_irrigation_stats(point_id: int = 1) -> str:
    """获取智能灌溉统计"""
    try:
        result = await java_client.get_smart_irrigation_stats(point_id=point_id)
        return json.dumps(result, ensure_ascii=False, indent=2)
    except Exception as e:
        return f"获取统计信息失败: {str(e)}"