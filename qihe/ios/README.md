# 契合 iOS

SwiftUI iPhone App 源码骨架。

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

后续建议用 Xcode 创建 iOS App 工程后，把该源码目录纳入 target，最低系统版本设为 iOS 17。

## 构建入口

当前仓库提供 `Package.swift`，用于在没有 `.xcodeproj` 时做源码级编译检查：

```bash
cd qihe/ios
swift build
```

真机或模拟器发布仍建议用 Xcode 创建 iOS App 工程，并把 `Qihe/` 源码目录纳入 target。

## 后端地址

默认后端地址是：

```txt
http://127.0.0.1:8000
```

真机联调时需要在 Xcode 工程的 Info.plist 中配置 `QIHE_API_BASE_URL`，值设为 Mac 的局域网地址，例如：

```txt
http://192.168.1.10:8000
```

源码级调试也可以通过环境变量覆盖：

```bash
QIHE_API_BASE_URL=http://192.168.1.10:8000 swift build
```
