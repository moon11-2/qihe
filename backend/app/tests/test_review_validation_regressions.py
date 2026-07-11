import pytest

from app.models.contracts import ContractSource
from app.services.contracts.review import normalize_review_result


SOURCE_TEXT = "第一条 付款安排\n甲方应在验收后付款，具体付款期限另行协商。"
SOURCE = ContractSource(text_preview=SOURCE_TEXT, char_count=len(SOURCE_TEXT))


def _normalize(payload: dict):
    return normalize_review_result(payload, SOURCE, SOURCE_TEXT).model_dump()


def test_empty_risk_array_without_strict_no_risk_signal_falls_back() -> None:
    result = _normalize(
        {
            "summary": "已完成审查。",
            "risk_level": "低风险",
            "score": 96,
            "clause_reviews": [],
        }
    )

    assert result["risk_items"]
    assert result["clause_reviews"]
    assert result["clause_reviews"][0]["clause_id"].startswith("fallback_")
    assert "未发现明显风险" not in result["summary"]


def test_all_invalid_risk_elements_fall_back() -> None:
    result = _normalize(
        {
            "summary": "存在风险。",
            "risk_level": "中风险",
            "clause_reviews": [
                {},
                None,
                "风险字符串",
                {"clause": "付款期限另行协商"},
                {"risk_title": "只有标题"},
                {"risk_analysis": "只有分析"},
            ],
        }
    )

    assert result["risk_items"]
    assert result["clause_reviews"][0]["clause_id"].startswith("fallback_")
    assert result["clause_reviews"][0]["risk_analysis"].startswith("规则兜底识别")


def test_mixed_risk_elements_fall_back_instead_of_silently_filtering() -> None:
    result = _normalize(
        {
            "summary": "付款期限需要核对。",
            "risk_level": "中风险",
            "score": 75,
            "clause_reviews": [
                {},
                "invalid",
                {
                    "risk_title": "付款期限不明确",
                    "risk_level": "中风险",
                    "risk_analysis": "未约定明确付款期限。",
                    "revision_suggestion": "补充具体付款日期。",
                },
            ],
        }
    )

    assert result["clause_reviews"]
    assert result["clause_reviews"][0]["clause_id"].startswith("fallback_")
    assert "付款期限不明确" not in [item["risk_title"] for item in result["clause_reviews"]]


def test_non_list_risk_field_falls_back_even_when_other_alias_is_valid() -> None:
    result = _normalize(
        {
            "summary": "付款期限需要核对。",
            "risk_level": "中风险",
            "clause_reviews": [
                {"risk_title": "付款期限不明确", "risk_analysis": "未约定明确付款期限。"},
            ],
            "risk_items": {"risk_title": "错误结构"},
        }
    )

    assert result["clause_reviews"]
    assert result["clause_reviews"][0]["clause_id"].startswith("fallback_")


def test_mismatched_risk_alias_arrays_fall_back() -> None:
    result = _normalize(
        {
            "summary": "付款期限需要核对。",
            "risk_level": "中风险",
            "clause_reviews": [
                {"risk_title": "付款期限不明确", "risk_analysis": "未约定明确付款期限。"},
            ],
            "risk_items": [],
        }
    )

    assert result["clause_reviews"]
    assert result["clause_reviews"][0]["clause_id"].startswith("fallback_")


def test_absolute_safety_claim_cannot_form_no_risk_result() -> None:
    result = _normalize(
        {
            "summary": "未发现明显风险，合同绝对安全。",
            "risk_level": "低风险",
            "score": 99,
            "clause_reviews": [],
        }
    )

    assert result["risk_items"]
    assert "合同绝对安全" not in result["summary"]
    assert "未发现明显风险" not in result["summary"]


@pytest.mark.parametrize(
    "summary",
    [
        "并非未发现明显风险，付款期限仍不明确。",
        "未发现明显风险的结论不成立。",
        "未发现明显风险，但存在付款违约风险。",
        "未发现明显风险，不过合同风险等级为中风险。",
        "不能排除付款风险，但未发现明显风险。",
        "未发现明显风险，但这不代表没有风险。",
    ],
)
def test_negated_or_contradictory_no_risk_summary_falls_back(summary: str) -> None:
    result = _normalize(
        {
            "summary": summary,
            "risk_level": "低风险",
            "score": 99,
            "clause_reviews": [],
        }
    )

    assert result["risk_items"]
    assert result["clause_reviews"][0]["clause_id"].startswith("fallback_")
    assert "未发现明显风险" not in result["summary"]


def test_absolute_safety_claim_is_removed_from_valid_risk_summary() -> None:
    result = _normalize(
        {
            "summary": "合同绝对安全，但付款期限仍需核对。",
            "risk_level": "中风险",
            "clause_reviews": [{"risk_title": "付款期限不明确", "risk_analysis": "需要核对付款日期。"}],
        }
    )

    assert result["risk_items"]
    assert "合同绝对安全" not in result["summary"]
    assert "绝对安全" not in result["summary"]


def test_other_absolute_safety_claims_are_removed() -> None:
    result = _normalize(
        {
            "summary": "合同完全安全、零风险，但付款期限仍需核对。",
            "risk_level": "中风险",
            "clause_reviews": [{"risk_title": "付款期限不明确", "risk_analysis": "需要核对付款日期。"}],
        }
    )

    assert result["risk_items"]
    assert "完全安全" not in result["summary"]
    assert "零风险" not in result["summary"]


def test_strict_no_risk_low_or_missing_score_is_normalized() -> None:
    for score, expected_score in ((None, 90), (12, 90), (89, 90), (96, 96), (120, 100)):
        result = _normalize(
            {
                "summary": "审查完成，未发现明显风险。",
                "risk_level": "低风险",
                "score": score,
                "clause_reviews": [],
            }
        )

        assert result["risk_items"] == []
        assert result["clause_reviews"] == []
        assert result["score"] == expected_score
        assert result["source"]["text_preview"] == SOURCE_TEXT
        assert result["blocks"]
