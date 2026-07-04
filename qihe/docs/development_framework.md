# 契合开发框架

## 当前 Git 基线

- 仓库根目录：`/Users/xiejackson/Documents/网页`
- 主分支：`main`
- 项目目录：`qihe/`
- 第一阶段目标：先保证骨架、边界、接口形状和验收方式稳定，再进入具体业务开发。

建议后续开发分支命名：

```txt
codex/backend-chat
codex/backend-contract-run
codex/ios-home-review
codex/ios-results-history
codex/export-word
```

## 分工

| 角色 | 负责范围 | 主要改动路径 | 完成标准 |
| --- | --- | --- | --- |
| 产品负责人 | 产品边界、页面文案、验收结论 | `qihe/docs/`、设计稿说明 | 确认只做 MVP 范围，不加入登录、会员、法律检索等扩展功能 |
| 后端开发 | FastAPI、文件处理、AI 网关、Word 导出 | `qihe/backend/app/` | API 按文档返回稳定结构，测试通过 |
| AI/Prompt 开发 | 千问 provider、审查/生成 prompt、JSON 稳定性 | `services/llm/`、`prompts/` | 审查和生成不能直接透传模型原文，必须结构化 |
| iOS 开发 | SwiftUI 页面、导航、本地历史、文件选择、分享导出 | `qihe/ios/Qihe/` | 页面符合 v3 视觉基准，历史只保存在本地 |
| QA/验收 | 核心路径、异常路径、真机体验 | `qihe/docs/`、测试记录 | 核心流程可走通，禁用能力没有入口 |
| Codex | 项目骨架、跨端契约、自动化测试、阶段性重构 | 全仓库 | 每次改动有清晰范围、可验证、可回滚 |

## 第一阶段任务拆分

### M0 项目骨架

- Git 仓库初始化到 `main`。
- 建立 `qihe/backend`、`qihe/ios`、`qihe/docs`。
- 后端 `GET /api/health` 可运行。
- API、模型、服务层、prompt 目录占位完成。
- iOS 源码按 App、DesignSystem、Features、Data 分层。

### M1 后端 MVP

- `/api/chat`：自由聊天和意图识别。
- `/api/files/upload`：只支持 PDF、DOCX、TXT。
- `/api/contracts/run`：支持 `review` 和 `generate`。
- `/api/contracts/export/word`：审查报告和合同草案导出 Word。
- 后端测试覆盖健康检查、上传类型限制、审查/生成结构。

### M2 iOS MVP

- 首页、历史抽屉、聊天/过程页。
- 合同审查页、合同生成页。
- 审查结果页：原文、风险、主体。
- 生成结果页：合同草案、待补充字段、签署前清单。
- SwiftData 本地历史，支持清空。

### M3 联调与真机

- iPhone 调后端 API。
- 文件选择、上传、导出分享。
- 断网状态和错误提示。
- 真机 UI 对齐 v3 视觉基准。

## 框架原则

1. MVP 边界优先  
   第一版只做自由聊天、合同审查、合同生成、文件上传、本地历史和 Word 导出。

2. 前后端职责清楚  
   iOS 负责交互、展示、本地历史、文件选择和分享；后端负责 AI 网关、文件抽取、结构化整理和 Word 导出。

3. 契约先行  
   API 请求和响应模型先稳定，页面和服务都围绕同一套结构开发。

4. AI 输出必须结构化  
   合同审查和合同生成不能把模型原文直接返回给 iPhone，后端必须整理成稳定 JSON。

5. 隐私默认保守  
   历史只保存在 iPhone 本地；后端不做账号、云端历史和用户画像。

6. 视觉遵循 v3  
   使用文书、印鉴、法务藏青的方向；朱砂只用于品牌和高风险，不做普通主按钮。

7. 不扩散功能  
   不在第一版加入登录、会员、客服、底部导航、图片 OCR、法律研究、法条检索、案例检索、类案分析、工商检索。

8. 小步可验收  
   每个阶段都要能运行、能测试、能说明差异，不用“大而全”的一次性交付。

## 验收标准

### Git 验收

- `git status --short` 没有未说明的脏文件。
- 首次骨架提交存在，提交信息清楚。
- `.gitignore` 覆盖 Python、Xcode、环境变量和本地运行产物。

### 后端骨架验收

- `cd qihe/backend && python -m pip install -e ".[dev]"` 可安装依赖。
- `python -m pytest` 通过。
- `uvicorn app.main:app --reload` 可启动。
- `GET /api/health` 返回 `{"status":"ok","service":"qihe-backend"}`。
- 后端目录包含 `api`、`models`、`services`、`prompts`、`tests`。

### iOS 骨架验收

- `QiheApp.swift` 存在。
- 源码分层包含 `App`、`DesignSystem`、`Features`、`Data`、`Resources`。
- 首页、历史、聊天、审查、生成、结果页面都有明确入口文件。
- 骨架中不出现登录、会员、客服、底部导航等第一版禁用能力。

### 产品边界验收

- 首页只规划合同审查和合同生成两个核心入口。
- 上传类型只规划 PDF、Word/DOCX、TXT。
- 历史只规划本地保存和清空。
- `法条依据` 只能作为审查结果字段展示，不能变成独立检索入口。

