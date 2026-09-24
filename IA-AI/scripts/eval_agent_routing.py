"""
Agent 路由准确率 / 工具触发率评测
=====================================

用 eval/agent_routing_dataset.json 的典型问句真实调用主 Agent，
从结果消息中提取实际触发的工具，统计：
- 路由准确率：实际触发工具命中 expect_any 的比例（整体 / 按专家分类）
- 工具触发率：每个类别下正确触发预期工具的比例

运行前提：
    1. 已配置 LLM（app/.env: OPENAI_API_KEY / OPENAI_MODEL）
    2. IA-server 已启动（只读工具会真实调用业务接口；数据集全部为只读问句，
       不会触发高危写操作）
    3. 无需 Postgres（不挂 checkpointer，单轮无记忆评测）

使用方法：
    cd IA-AI
    python scripts/eval_agent_routing.py
    python scripts/eval_agent_routing.py --show-fail

所有数字来自真实跑测，禁止人工修改输出。
"""
import argparse
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

DATASET_PATH = Path(__file__).parent.parent / "eval" / "agent_routing_dataset.json"


def extract_triggered_tools(result_messages: list) -> set[str]:
    """从 Agent 结果消息中提取实际调用的工具名"""
    triggered: set[str] = set()
    for msg in result_messages:
        for call in getattr(msg, "tool_calls", None) or []:
            name = call.get("name") if isinstance(call, dict) else getattr(call, "name", None)
            if name:
                triggered.add(name)
        # ToolMessage 的 name 字段（实际执行过的工具）
        if getattr(msg, "type", None) == "tool":
            name = getattr(msg, "name", None)
            if name:
                triggered.add(name)
    return triggered


async def evaluate(show_fail: bool) -> dict:
    from langchain_core.messages import HumanMessage
    from app.agent.assistant import build_main_agent

    agent = build_main_agent()  # 无 checkpointer，单轮评测
    dataset = json.loads(DATASET_PATH.read_text(encoding="utf-8"))

    total = 0
    correct = 0
    by_category: dict[str, dict[str, int]] = {}
    failures = []

    for i, item in enumerate(dataset):
        question = item["question"]
        expect = item["expect_any"]
        category = item.get("category", "other")
        total += 1

        try:
            result = await agent.ainvoke(
                {"messages": [HumanMessage(content=question)]},
                {"configurable": {"thread_id": f"eval_{i}"}},
            )
            messages = result.get("messages", []) if isinstance(result, dict) else []
            triggered = extract_triggered_tools(messages)
        except Exception as e:
            triggered = set()
            print(f"  [异常] {question}: {e}")

        hit = bool(triggered & set(expect))
        correct += int(hit)
        bucket = by_category.setdefault(category, {"total": 0, "correct": 0})
        bucket["total"] += 1
        bucket["correct"] += int(hit)

        if not hit:
            failures.append({
                "question": question,
                "expect_any": expect,
                "triggered": sorted(triggered),
            })
        print(f"  [{'OK' if hit else 'X'}] {question} -> {sorted(triggered) or '(无工具调用)'}")

    accuracy = correct / total if total else 0.0
    category_report = {
        c: {"total": b["total"], "correct": b["correct"],
            "accuracy": round(b["correct"] / b["total"], 4) if b["total"] else 0.0}
        for c, b in by_category.items()
    }

    if show_fail and failures:
        print(f"\n未命中 {len(failures)} 条:")
        for f in failures:
            print(f"  - {f['question']}\n    期望: {f['expect_any']}  实际: {f['triggered']}")

    return {
        "total": total,
        "correct": correct,
        "routing_accuracy": round(accuracy, 4),
        "by_category": category_report,
        "failures": failures,
    }


def main():
    parser = argparse.ArgumentParser(description="Agent 路由准确率评测")
    parser.add_argument("--show-fail", action="store_true", help="打印未命中明细")
    args = parser.parse_args()

    print("=" * 56)
    print("Agent 路由准确率 / 工具触发率评测（真实调用主 Agent）")
    print("=" * 56)

    report = asyncio.run(evaluate(args.show_fail))

    print("\n" + "=" * 56)
    print(f"整体路由准确率: {report['routing_accuracy']:.2%} "
          f"({report['correct']}/{report['total']})")
    for category, stat in report["by_category"].items():
        print(f"  {category:18s} {stat['accuracy']:.2%} ({stat['correct']}/{stat['total']})")
    print("=" * 56)

    out = Path(__file__).parent.parent / "eval" / "agent_routing_report.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"报告已保存: {out}")


if __name__ == "__main__":
    main()
