# 契合后端

FastAPI 后端负责 AI 网关、文件处理、合同审查/生成结构化整理和 Word 导出。

## 启动

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
uvicorn app.main:app --reload
```

如果仓库位于 Documents、iCloud Drive 或其他同步目录，推荐把虚拟环境放到 `/tmp`，避免同步机制损坏 `.venv` 或 `egg-info`：

```bash
python3 -m venv /tmp/qihe-backend-venv
source /tmp/qihe-backend-venv/bin/activate
python -m pip install -U pip
python -m pip install -e ".[dev]"
python -m pytest
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## 接口

- `GET /api/health`
- `POST /api/chat`
- `POST /api/files/upload`
- `POST /api/contracts/run`
- `POST /api/contracts/export/word`

当前接口已具备 MVP 契约能力：聊天、合同审查、合同生成、文件上传解析和 Word 导出均有基础实现与测试覆盖；真实 AI 网关和更完整的合同规则可按开发文档继续增强。
