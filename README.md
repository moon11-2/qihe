# 契合

`契合` 是一款面向 iPhone 的 AI 合同审查与生成助手。

当前仓库阶段：项目 Git 与开发骨架已建立，后端具备最小可运行入口，iOS 端已按 SwiftUI 模块边界建好源码目录。

## 目录

```txt
qihe/
  backend/   FastAPI 后端
  ios/       SwiftUI iPhone App 源码骨架
  docs/      分工、原则、验收与协作说明
```

## 后端本地启动

```bash
cd qihe/backend
python -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[dev]"
uvicorn app.main:app --reload
```

健康检查：

```bash
curl http://127.0.0.1:8000/api/health
```

## 协作入口

- 开发分工、原则、验收：[qihe/docs/development_framework.md](qihe/docs/development_framework.md)
- iOS、后端、AI Prompt 负责人提示词：[qihe/docs/role_prompts.md](qihe/docs/role_prompts.md)
- 后端说明：[qihe/backend/README.md](qihe/backend/README.md)
- iOS 说明：[qihe/ios/README.md](qihe/ios/README.md)
