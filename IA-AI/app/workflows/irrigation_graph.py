"""
智能灌溉决策 LangGraph 工作流
=====================================

把 Java 侧 SmartIrrigationServiceImpl.buildSmartPlan() 的写死串行逻辑
重构为 IA-AI 侧的 StateGraph 编排：

    湿度预测(predict) → 风险系数计算(risk) → 条件边决策(decide)
        ├─ 不灌 → END
        └─ 灌溉 → 人审(review, interrupt) → 执行(execute) → 学习回写(learn) → END

与对话型多 Agent（主 Agent + 只读专家）互补，这是编排型工作流形态。

决策规则与 Java 侧保持一致：
- 当前湿度 < 阈值        -> adaptive（自适应，立即灌溉）
- 预测将低于阈值          -> predictive（预测式，预防灌溉）
- 否则                    -> 不灌溉（stage_based / standard）

水量/时长等数值计算复用 Java 的 /smart-irrigation/plan（不在 Python 重复实现），
本工作流负责的是"编排"：节点拆分、条件分支、人审中断、执行与学习回写。

在线学习回写说明：Java 生产链路中 complete 回调由灌溉实际结束时触发；
工作流为演示闭环，在执行启动后读取当前湿度立即回调（learn 节点注释处可改为定时触发）。
"""
import logging
from typing import Any, Optional, TypedDict

from langgraph.graph import END, StateGraph
from langgraph.types import interrupt

from app.services.http_client import java_client

logger = logging.getLogger(__name__)

DEFAULT_THRESHOLD = 40.0


class IrrigationWorkflowState(TypedDict, total=False):
    point_id: int
    threshold: float
    current_moisture: Optional[float]
    prediction: dict
    strategy: dict
    learned: dict
    decision: dict
    execute_result: dict
    learn_result: dict
    steps: list[str]


# ----------------------------------------------------------------------
# 节点实现
# ----------------------------------------------------------------------

async def predict_node(state: IrrigationWorkflowState) -> dict:
    """节点1：湿度预测（当前湿度 + 未来 2/4/6h 预测与预防性分析）"""
    point_id = state["point_id"]
    threshold = state.get("threshold", DEFAULT_THRESHOLD)

    env = await java_client.get_current_environment(point_id=point_id)
    prediction = await java_client.analyze_moisture_prediction(
        point_id=point_id, threshold=threshold)

    current = None
    if isinstance(env, dict) and env.get("soilMoisture") is not None:
        current = float(env["soilMoisture"])

    return {
        "current_moisture": current,
        "prediction": prediction if isinstance(prediction, dict) else {},
        "steps": state.get("steps", []) + [
            f"湿度预测: 当前 {current}%，预测分析完成"
        ],
    }


async def risk_node(state: IrrigationWorkflowState) -> dict:
    """节点2：生育期/环境风险系数（灌溉策略 + 在线学习参数）"""
    point_id = state["point_id"]
    strategy: dict = {}
    learned: dict = {}
    try:
        result = await java_client.get_irrigation_strategy(point_id=point_id)
        strategy = result if isinstance(result, dict) else {}
    except Exception as e:
        logger.warning(f"获取灌溉策略失败，按无作物配置处理: {e}")
    try:
        result = await java_client.get_learned_params(point_id=point_id)
        learned = result if isinstance(result, dict) else {}
    except Exception as e:
        logger.warning(f"获取学习参数失败，按默认系数处理: {e}")

    stage = strategy.get("currentStage", "未配置")
    factor = strategy.get("irrigationFactor", 1.0)
    return {
        "strategy": strategy,
        "learned": learned,
        "steps": state.get("steps", []) + [
            f"风险系数: 生育期={stage}, 灌溉系数={factor}"
        ],
    }


async def decide_node(state: IrrigationWorkflowState) -> dict:
    """节点3：条件决策（自适应 / 预测式 / 不灌），规则与 Java 侧一致"""
    threshold = state.get("threshold", DEFAULT_THRESHOLD)
    current = state.get("current_moisture")
    prediction = state.get("prediction") or {}
    strategy = state.get("strategy") or {}

    if current is None:
        decision = {
            "should_irrigate": False,
            "decision_type": "standard",
            "reason": "缺少环境数据",
        }
    elif current < threshold:
        decision = {
            "should_irrigate": True,
            "decision_type": "adaptive",
            "reason": f"当前湿度 {current:.1f}% 低于阈值 {threshold:.0f}%，需要立即灌溉",
        }
    elif prediction.get("needPreIrrigation"):
        decision = {
            "should_irrigate": True,
            "decision_type": "predictive",
            "reason": prediction.get("reason", "预测湿度将低于阈值，预防性灌溉"),
        }
    else:
        decision = {
            "should_irrigate": False,
            "decision_type": "stage_based" if strategy.get("hasCropConfig") else "standard",
            "reason": prediction.get("reason", "湿度在合理范围内"),
        }

    # 需要灌溉时，复用 Java 的水量/时长计算（不在 Python 重复实现）
    if decision["should_irrigate"]:
        try:
            plan = await java_client.get_smart_irrigation_plan(point_id=state["point_id"])
            if isinstance(plan, dict):
                decision["water_amount_l"] = plan.get("waterAmountL")
                decision["duration_seconds"] = plan.get("durationSeconds")
                decision["target_moisture"] = plan.get("targetMoisture")
        except Exception as e:
            logger.warning(f"获取水量计算失败: {e}")

    return {
        "decision": decision,
        "steps": state.get("steps", []) + [
            f"条件决策: {decision['decision_type']} -> "
            f"{'灌溉' if decision['should_irrigate'] else '不灌'}（{decision['reason']}）"
        ],
    }


def route_after_decide(state: IrrigationWorkflowState) -> str:
    """条件边：需要灌溉 -> 人审；否则直接结束"""
    decision = state.get("decision") or {}
    return "review" if decision.get("should_irrigate") else END


async def human_review_node(state: IrrigationWorkflowState) -> dict:
    """节点4：人审（interrupt 暂停，等待 /workflow/resume 恢复）"""
    decision = state["decision"]
    water = decision.get("water_amount_l")
    duration = decision.get("duration_seconds")
    summary = (
        f"监测点 {state['point_id']} {decision['reason']}"
        + (f"，计划灌溉 {water}L（约 {duration} 秒）" if water else "")
    )
    approval = interrupt({
        "type": "approval_request",
        "tool": "smart_irrigation_workflow",
        "args": {
            "point_id": state["point_id"],
            "decision_type": decision["decision_type"],
            "water_amount_l": water,
            "duration_seconds": duration,
        },
        "summary": summary,
    })
    approved = isinstance(approval, dict) and approval.get("approved")
    return {
        "steps": state.get("steps", []) + [
            "人审: 已批准执行" if approved else "人审: 用户拒绝，终止流程"
        ],
        "execute_result": {"approved": bool(approved)},
    }


async def execute_node(state: IrrigationWorkflowState) -> dict:
    """节点5：执行灌溉（人审拒绝则跳过）"""
    prev = state.get("execute_result") or {}
    if not prev.get("approved"):
        return {"execute_result": {**prev, "skipped": True}}

    result = await java_client.execute_smart_irrigation(
        payload={}, point_id=state["point_id"])
    log_id = result.get("id") if isinstance(result, dict) else None
    return {
        "execute_result": {**prev, "skipped": False, "log_id": log_id, "raw": result},
        "steps": state.get("steps", []) + [f"执行: 灌溉已启动（记录 #{log_id}）"],
    }


async def learn_node(state: IrrigationWorkflowState) -> dict:
    """节点6：在线学习回写（记录灌溉后湿度，触发参数修正）

    简化说明：生产链路中 complete 回调应在灌溉实际结束、湿度稳定后触发
    （Java 侧定时任务）；工作流为演示完整闭环，启动后即读当前湿度回写。
    """
    execute = state.get("execute_result") or {}
    if execute.get("skipped") or not execute.get("log_id"):
        return {"learn_result": {"skipped": True}}

    env = await java_client.get_current_environment(point_id=state["point_id"])
    after = env.get("soilMoisture") if isinstance(env, dict) else None
    if after is None:
        return {"learn_result": {"skipped": True, "reason": "无灌溉后湿度数据"}}

    await java_client.complete_smart_irrigation(
        log_id=int(execute["log_id"]), soil_moisture_after=float(after))
    return {
        "learn_result": {"skipped": False, "soil_moisture_after": after},
        "steps": state.get("steps", []) + [
            f"学习回写: 灌溉后湿度 {after}%，参数已修正"
        ],
    }


# ----------------------------------------------------------------------
# 图构建
# ----------------------------------------------------------------------

def build_irrigation_workflow(checkpointer=None):
    """构建智能灌溉决策工作流（编译后的 LangGraph）"""
    graph = StateGraph(IrrigationWorkflowState)

    graph.add_node("predict", predict_node)
    graph.add_node("risk", risk_node)
    graph.add_node("decide", decide_node)
    graph.add_node("review", human_review_node)
    graph.add_node("execute", execute_node)
    graph.add_node("learn", learn_node)

    graph.set_entry_point("predict")
    graph.add_edge("predict", "risk")
    graph.add_edge("risk", "decide")
    graph.add_conditional_edges("decide", route_after_decide, {"review": "review", END: END})
    graph.add_edge("review", "execute")
    graph.add_edge("execute", "learn")
    graph.add_edge("learn", END)

    return graph.compile(checkpointer=checkpointer)
