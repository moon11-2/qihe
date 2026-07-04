from app.models.contracts import ContractRunRequest


def build_generate_placeholder(request: ContractRunRequest) -> dict:
    return {
        "title": "合同草案",
        "draft": "合同生成能力将在 M1 接入千问后返回真实草案。",
        "missing_fields": [],
        "pre_sign_checklist": [
            "确认双方主体信息",
            "确认金额和期限",
            "确认争议解决方式",
        ],
        "source": {
            "text_preview": (request.text or "")[:120],
            "file_id": request.file_id,
        },
    }

