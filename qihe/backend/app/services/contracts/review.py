from app.models.contracts import ContractRunRequest


def build_review_placeholder(request: ContractRunRequest) -> dict:
    return {
        "title": "合同审查报告",
        "summary": "审查能力将在 M1 接入千问后返回真实结果。",
        "review_basis": "中国大陆现行法律",
        "risk_level": "pending",
        "score": None,
        "source": {
            "text_preview": (request.text or "")[:120],
            "file_id": request.file_id,
        },
        "clause_reviews": [],
        "parties": {},
    }

