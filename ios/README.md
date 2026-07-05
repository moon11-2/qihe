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

## 后端地址

默认后端地址是：

```txt
http://127.0.0.1:8010
```

仓库提交了 shared Xcode Scheme，直接在 Xcode 里 Run `Qihe` 时会注入：

```txt
QIHE_API_BASE_URL=http://127.0.0.1:8010
```

本机联调前请先启动后端：

```bash
cd backend
uvicorn app.main:app --host 127.0.0.1 --port 8010
```

如果 8010 被占用，或真机联调需要访问 Mac 的局域网地址，可在 Xcode Scheme 的 Run > Arguments > Environment Variables 中覆盖 `QIHE_API_BASE_URL`，例如：

```txt
http://192.168.1.10:8010
```

源码级调试和命令行运行也可以通过环境变量覆盖：

```bash
QIHE_API_BASE_URL=http://192.168.1.10:8010 swift build
```
