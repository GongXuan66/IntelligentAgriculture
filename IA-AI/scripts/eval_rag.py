"""
RAG 检索质量评测：Hit Rate / MRR
=====================================

用 eval/rag_eval_dataset.json 的标注问句跑真实检索，统计：
- Hit Rate@K：期望文档块出现在前 K 条结果中的比例
- MRR@K：期望文档块首次出现位置的倒数均值

三种模式对比（简历"优化前后"数字的来源）：
    python scripts/eval_rag.py --mode vector           # 纯向量（优化前基线）
    python scripts/eval_rag.py --mode hybrid           # BM25+向量 RRF（第二批）
    python scripts/eval_rag.py --mode hybrid+rerank    # 混合检索+精排（第三批，需 rerank 依赖）

判定规则：结果来源文件名包含 expect.source、且内容或章节包含
expect.section 关键词，视为命中。

运行前提：索引已按余弦距离重建（scripts/rebuild_index.py）。
所有数字来自真实跑测，禁止人工修改输出。
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from app.rag.config import rag_settings  # noqa: E402
from app.rag.retriever import rag_retriever  # noqa: E402

DATASET_PATH = Path(__file__).parent.parent / "eval" / "rag_eval_dataset.json"


def is_hit(result: dict, expect: dict) -> bool:
    source = str(result.get("source", ""))
    if expect["source"] not in source:
        return False
    meta = result.get("metadata") or {}
    haystack = result.get("content", "") + " " + " ".join(
        str(meta.get(f"h{i}", "")) for i in range(1, 5)
    )
    return expect["section"] in haystack


def evaluate(mode: str, top_k: int) -> dict:
    dataset = json.loads(DATASET_PATH.read_text(encoding="utf-8"))

    hybrid_retriever = None
    if mode in ("hybrid", "hybrid+rerank"):
        from app.rag.hybrid import hybrid_retriever as hr
        hybrid_retriever = hr
        if mode == "hybrid+rerank":
            rag_settings.rerank_enabled = True

    hits = 0
    rr_sum = 0.0
    details = []

    for item in dataset:
        question = item["question"]
        expect = item["expect"]

        if mode == "vector":
            results = rag_retriever.search(question, top_k=top_k)
        else:
            results = hybrid_retriever.search([question], top_k=top_k)

        rank = None
        for i, r in enumerate(results, 1):
            if is_hit(r, expect):
                rank = i
                break

        hit = rank is not None
        hits += int(hit)
        rr_sum += 1.0 / rank if hit else 0.0
        details.append({
            "question": question,
            "expect": f"{expect['source']}#{expect['section']}",
            "rank": rank,
            "hit": hit,
        })

    n = len(dataset)
    return {
        "mode": mode,
        "top_k": top_k,
        "total": n,
        "hit_rate": round(hits / n, 4),
        "mrr": round(rr_sum / n, 4),
        "details": details,
    }


def main():
    parser = argparse.ArgumentParser(description="RAG 检索质量评测")
    parser.add_argument("--mode", default="hybrid",
                        choices=["vector", "hybrid", "hybrid+rerank"])
    parser.add_argument("--top-k", type=int, default=5)
    parser.add_argument("--show-miss", action="store_true", help="打印未命中明细")
    args = parser.parse_args()

    report = evaluate(args.mode, args.top_k)

    print("=" * 56)
    print(f"模式: {report['mode']}  top_k: {report['top_k']}  问句数: {report['total']}")
    print(f"Hit Rate@{args.top_k}: {report['hit_rate']:.2%}")
    print(f"MRR@{args.top_k}:      {report['mrr']:.4f}")
    print("=" * 56)

    if args.show_miss:
        misses = [d for d in report["details"] if not d["hit"]]
        print(f"\n未命中 {len(misses)} 条:")
        for d in misses:
            print(f"  - {d['question']}  (期望 {d['expect']})")

    # 结果落盘，供优化前后对比
    out = Path(__file__).parent.parent / "eval" / f"rag_eval_{args.mode}.json"
    out.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\n报告已保存: {out}")


if __name__ == "__main__":
    main()
