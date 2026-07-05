# 契合 iOS

SwiftUI iPhone App 工程。

当前阶段先建立模块边界：

```txt
Qihe/
  QiheApp.swift
  App/
  DesignSystem/
  Features/
  Data/
  Resources/
```

当前已提供 `Qihe.xcodeproj`，可以直接用 Xcode 打开：

```bash
open ios/Qihe.xcodeproj
```

## 构建入口

当前仓库提供 `Package.swift`，用于在没有 `.xcodeproj` 时做源码级编译检查：

```bash
cd ios
swift build
```

正式 iOS App target 构建：

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Qihe.xcodeproj \
  -scheme Qihe \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' \
  -derivedDataPath /tmp/qihe-AppDerivedData \
  build
```

使用 `/tmp/qihe-AppDerivedData` 是为了避免某些同步目录里的扩展属性影响 iOS 签名。

如果仓库位于 Documents、iCloud Drive 或其他同步目录，并且 `xcodebuild` 卡在项目读取阶段，可先把 iOS 工程复制到 `/tmp` 或把仓库迁到非同步目录后再构建。

## API Base 环境策略

iOS App 的 API Base 按以下优先级读取：

1. Xcode Scheme 或运行环境里的 `QIHE_API_BASE_URL`
2. `Info.plist` 里的 `QIHE_API_BASE_URL`
3. 代码默认值 `https://api.qihe1.xyz`

仓库提交的 shared Xcode Scheme 默认注入正式 HTTPS 后端：

```txt
QIHE_API_BASE_URL=https://api.qihe1.xyz
```

这个值不要附带 `/api`，因为客户端请求路径已经包含 `/api/...`。

请求路径由客户端统一拼接为 `/api/...`，例如健康检查会访问：

```txt
https://api.qihe1.xyz/api/health
```

本机联调前请先启动后端：

```bash
cd backend
uvicorn app.main:app --host 127.0.0.1 --port 8010
```

然后在 Xcode Scheme 的 Run > Arguments > Environment Variables 中临时覆盖：

```txt
QIHE_API_BASE_URL=http://127.0.0.1:8010
```

如果 8010 被占用，或真机联调需要访问 Mac 的局域网地址，可在 Xcode Scheme 的 Run > Arguments > Environment Variables 中覆盖 `QIHE_API_BASE_URL`，例如：

```txt
http://192.168.1.10:8010
```

`Info.plist` 只保留 `NSAllowsLocalNetworking`，用于本机和局域网调试。正式公网 API 必须使用 HTTPS 域名，不应为公网 IP 添加明文 HTTP ATS 例外。

源码级调试和命令行运行也可以通过环境变量覆盖：

```bash
QIHE_API_BASE_URL=http://192.168.1.10:8010 swift build
```

## 第一阶段真机验收重点

- 首页、审查、生成、对话默认连接 `https://api.qihe1.xyz/api/...`。
- 后端核心能力需要登录 token；未登录时 App 会引导到“我的”页，后端请求会返回 `auth_required`。
- 首页、聊天页、审查输入页、生成输入页支持滚动、点击空白和提交后收起键盘。
- “我的”页已接入后端 `/api/auth/register`、`/api/auth/login` 和真实 token；注册只需要邮箱、密码和可选昵称，不需要验证码。
