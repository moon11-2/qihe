# 契合后端

FastAPI 后端负责 AI 网关、文件处理、合同审查/生成结构化整理和 Word 导出。

## 启动

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
uvicorn app.main:app --reload
```

## 接口

- `GET /api/health`
- `POST /api/chat`
- `POST /api/files/upload`
- `POST /api/contracts/run`
- `POST /api/contracts/export/word`

当前阶段除健康检查外均为契约占位，后续按开发文档逐步接入真实能力。

