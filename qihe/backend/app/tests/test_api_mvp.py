from io import BytesIO
from pathlib import Path

from docx import Document
from fastapi.testclient import TestClient
from pypdf import PdfWriter

from app.core.config import settings
from app.main import create_app
from app.services.files import storage


def _client(tmp_path: Path, monkeypatch) -> TestClient:
    monkeypatch.setattr(storage, "UPLOAD_DIR", tmp_path)
    return TestClient(create_app())


def test_upload_supported_file_types(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)

    txt_response = client.post(
        "/api/files/upload",
        files={"file": ("contract.txt", b"hello contract", "text/plain")},
    )
    assert txt_response.status_code == 200
    assert txt_response.json()["status"] == "accepted"
    assert txt_response.json()["char_count"] > 0

    docx_buffer = BytesIO()
    document = Document()
    document.add_paragraph("DOCX contract text")
    document.save(docx_buffer)
    docx_response = client.post(
        "/api/files/upload",
        files={
            "file": (
                "contract.docx",
                docx_buffer.getvalue(),
                "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            )
        },
    )
    assert docx_response.status_code == 200
    assert "DOCX contract text" in docx_response.json()["text_preview"]

    pdf_buffer = BytesIO()
    writer = PdfWriter()
    writer.add_blank_page(width=72, height=72)
    writer.write(pdf_buffer)
    pdf_response = client.post(
        "/api/files/upload",
        files={"file": ("contract.pdf", pdf_buffer.getvalue(), "application/pdf")},
    )
    assert pdf_response.status_code == 200
    assert pdf_response.json()["filename"] == "contract.pdf"


def test_upload_rejects_images_and_large_files(tmp_path: Path, monkeypatch) -> None:
    client = _client(tmp_path, monkeypatch)

    image_response = client.post(
        "/api/files/upload",
        files={"file": ("photo.png", b"not accepted", "image/png")},
    )
    assert image_response.status_code == 400
    assert image_response.json()["error"]["code"] == "unsupported_file_type"

    monkeypatch.setattr(settings, "max_upload_mb", 0)
    large_response = client.post(
        "/api/files/upload",
        files={"file": ("contract.txt", b"x", "text/plain")},
    )
    assert large_response.status_code == 413
    assert large_response.json()["error"]["code"] == "file_too_large"


def test_chat_response_shapes() -> None:
    client = TestClient(create_app())

    route_response = client.post(
        "/api/chat",
        json={"messages": [{"role": "user", "content": "帮我审查这份合同风险"}]},
    )
    assert route_response.status_code == 200
    assert route_response.json()["type"] == "route"
    assert route_response.json()["route"] == "review"

    need_input_response = client.post(
        "/api/chat",
        json={"messages": [{"role": "user", "content": "合同"}]},
    )
    assert need_input_response.status_code == 200
    assert need_input_response.json()["type"] == "need_input"
    assert need_input_response.json()["options"] == ["review", "generate"]

    chat_response = client.post(
        "/api/chat",
        json={"messages": [{"role": "user", "content": "你好"}]},
    )
    assert chat_response.status_code == 200
    assert chat_response.json()["type"] == "chat"


def test_contract_run_review_and_generate_shapes() -> None:
    client = TestClient(create_app())

    review_response = client.post(
        "/api/contracts/run",
        json={
            "mode": "review",
            "text": "甲方：甲公司\n乙方：乙公司\n双方签订服务合同，金额为人民币10000元。",
        },
    )
    assert review_response.status_code == 200
    review_json = review_response.json()
    assert review_json["type"] == "review_result"
    assert review_json["review_result"]["title"] == "合同审查报告"
    assert isinstance(review_json["review_result"]["risk_items"], list)
    assert review_json["review_result"]["parties"]["party_a"] == "甲公司"
    assert review_json["review_result"]["parties"]["party_b"] == "乙公司"

    generate_response = client.post(
        "/api/contracts/run",
        json={
            "mode": "generate",
            "text": "生成一份服务合同",
            "metadata": {
                "contract_type": "服务合同",
                "party_a": "甲公司",
                "party_b": "乙公司",
                "amount": "10000元",
                "term": "2026年7月1日至2026年12月31日",
                "jurisdiction": "甲方所在地人民法院",
            },
        },
    )
    assert generate_response.status_code == 200
    generate_json = generate_response.json()
    assert generate_json["type"] == "generate_result"
    assert "服务合同" in generate_json["generate_result"]["draft"]

    text_only_generate_response = client.post(
        "/api/contracts/run",
        json={
            "mode": "generate",
            "text": "生成一份服务合同，甲方甲公司，乙方乙公司，金额10000元，期限6个月。",
        },
    )
    assert text_only_generate_response.status_code == 200
    text_only_generate_json = text_only_generate_response.json()
    assert "甲公司" in text_only_generate_json["generate_result"]["draft"]
    assert "10000元" in text_only_generate_json["generate_result"]["draft"]


def test_word_export_can_be_opened() -> None:
    client = TestClient(create_app())
    response = client.post(
        "/api/contracts/export/word",
        json={
            "type": "generate",
            "title": "服务合同草案",
            "payload": {
                "draft": "服务合同\n\n甲方：甲公司\n乙方：乙公司",
                "missing_fields": ["履行期限"],
                "pre_sign_checklist": ["核对主体信息"],
            },
        },
    )

    assert response.status_code == 200
    assert response.content.startswith(b"PK")
    exported = Document(BytesIO(response.content))
    paragraphs = [paragraph.text for paragraph in exported.paragraphs]
    assert "服务合同草案" in paragraphs
    assert "履行期限" in paragraphs
