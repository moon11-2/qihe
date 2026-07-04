# 契合

移动端 AI 合同助手原型，基于 uni-app Vue3 + TypeScript。当前重点功能：

- 合同审查
- 合同生成
- 首页自由输入与意图识别
- 本地记录与设置页原型
- Dify Chatflow 接入预留

## 环境要求

- Node.js
- npm
- HBuilderX / Xcode 仅在后续打包 App 或 iOS 内测时需要

## 本地启动

```bash
npm install
npm run dev:h5 -- --host 127.0.0.1
```

打开：

```text
http://127.0.0.1:5173/
```

默认是 `Mock` 模式，不需要 Dify Key 就能试用界面、合同审查、合同生成和首页闲聊引导。

## Dify 接入

复制 `.env.example` 为 `.env.local`，填入 Dify App API Key：

```env
DIFY_API_BASE_URL=https://api.dify.ai/v1
DIFY_API_KEY=your-dify-app-api-key
VITE_DIFY_ENABLED=true
VITE_DIFY_PROXY_PATH=/api/dify
```

然后重启开发服务器。

注意：不要提交 `.env.local`，不要把真实 Dify token、cookie、API key 写入仓库。

## Xcode / 模拟器连接真实 Dify

Xcode 包内的 WebApp 不能使用 Vite 开发代理，所以本项目提供一个本机 Dify 代理：

```bash
npm run dify:proxy
```

另开一个终端同步带 Dify 配置的 iOS WebApp：

```bash
npm run sync:ios:dify
```

然后在 Xcode 或模拟器里重新运行 `HetongBang`。这是当前 iOS wrapper 的工程名，App 内展示的产品名是“契合”。模拟器会请求：

```text
http://127.0.0.1:8787/api/dify
```

真实 `DIFY_API_KEY` 只放在本地 `.env.local`，不会写进前端 JS 和 Git。

## 构建

```bash
npm run build:h5
```

构建产物在 `dist/`，该目录不会提交到 Git。

## iPhone 真机试用

Xcode 工程位于：

```text
ios/HetongBang/HetongBang.xcodeproj
```

同步最新 H5 到 Xcode：

```bash
./scripts/sync-ios-webapp.sh
```

然后用 Xcode 打开工程，选择 `HetongBang` scheme 和你的 iPhone，配置签名后运行。

详细说明见 `docs/ios-xcode-run.md`。

## 关键文件

- `src/pages/index/index.vue`：主界面和原型交互
- `src/services/dify.ts`：Dify / Mock 统一服务层
- `ios/HetongBang/HetongBang.xcodeproj`：iPhone 真机试用 Xcode 工程
- `scripts/dify-proxy.mjs`：Xcode/模拟器本机 Dify 转发代理
- `docs/dify/hetongbang-chatflow.dsl.yml`：早期 Dify Chatflow DSL，后续接入时按“契合”口径收敛为审查 / 生成两条主链路
- `docs/dify/hetongbang-workflow-plan.md`：工作流方案
- `docs/dify/frontend-integration.md`：前端接入说明
- `docs/dify-output-contract.md`：Dify 输出契约
