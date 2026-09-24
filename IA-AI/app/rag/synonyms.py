"""
农业领域同义词扩展（纯规则，无 LLM 成本）。

检索前把 query 中命中的领域词替换为同义词，生成额外的检索变体，
提升中文短 query 的召回率（如"西红柿"也能命中"番茄"的文档块）。

维护原则：
- 只收农业 / 本系统高频词，同义关系必须真实，宁缺毋滥
- 过宽的词（如"湿度"≈"墒情"）不放，避免语义漂移反而引入噪声
"""
from typing import List, Set

# 同义词组：组内词互为同义
SYNONYM_GROUPS: List[Set[str]] = [
    {"西红柿", "番茄"},
    {"黄瓜", "青瓜"},
    {"土豆", "马铃薯"},
    {"玉米", "苞米"},
    {"大棚", "温室", "设施大棚"},
    {"滴灌", "微灌"},
    {"灌溉", "浇水"},
    {"喷灌", "喷淋"},
    {"风机", "风扇", "通风机"},
    {"卷帘机", "卷帘"},
    {"补光灯", "生长灯"},
    {"生育期", "生长期", "生长阶段"},
    {"苗期", "幼苗期"},
    {"抽穗期", "抽穗"},
    {"开花期", "花期"},
    {"结果期", "坐果期"},
    {"施肥", "追肥"},
    {"病虫害", "病虫害防治"},
    {"霜霉病", "霜霉"},
    {"蚜虫", "腻虫"},
    {"红蜘蛛", "叶螨"},
    {"墒情", "土壤水分"},
    {"降温", "通风降温"},
    {"监测点", "检测点"},
]

# 词 -> 所在同义词组索引（一词最多属于一组，多义取首组）
_TERM_TO_GROUP: dict = {}
for _i, _group in enumerate(SYNONYM_GROUPS):
    for _term in _group:
        _TERM_TO_GROUP.setdefault(_term, _i)


def expand_with_synonyms(query: str, max_variants: int = 2) -> List[str]:
    """
    对 query 做同义词扩展。

    命中词典中的词时，生成"替换为同义词"的变体 query。
    每个命中词最多产生 max_variants 个变体，返回列表不含原 query。

    Args:
        query: 原始查询
        max_variants: 每个词最多扩展的同义词数

    Returns:
        变体 query 列表（可能为空）
    """
    variants: List[str] = []
    for term, group_idx in _TERM_TO_GROUP.items():
        if term not in query:
            continue
        synonyms = [w for w in SYNONYM_GROUPS[group_idx] if w != term]
        for syn in synonyms[:max_variants]:
            variant = query.replace(term, syn)
            if variant != query and variant not in variants:
                variants.append(variant)
    return variants
