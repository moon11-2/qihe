# iOS与AppStore上架准备文档

日期：2026-07-04  
项目名称：契合  
适用对象：iOS 开发、上线负责人、App Store 提交负责人

## 1. 文档用途

本文档说明当前 iOS wrapper 状态，以及如果要上架 App Store，还需要完成哪些工作。

## 2. 当前 iOS 工程状态

当前 iOS 工程是轻量壳：

```text
ios/HetongBang/HetongBang.xcodeproj
```

技术路线：

- SwiftUI
- WKWebView
- 内置 H5 静态资源
- 通过脚本同步 H5 构建产物

工程名仍为 `HetongBang`，App 内产品展示名为“契合”。后续上架前可决定是否统一工程名和 Bundle ID。

## 3. 同步 H5 到 iOS

默认同步：

```bash
cd /Users/lantian/Documents/合同审查
npm run sync:ios
```

带本地 Dify 配置同步：

```bash
npm run sync:ios:dify
```

同步脚本：

```text
scripts/sync-ios-webapp.sh
```

注意：当前最新前端改动尚未自动同步到 iOS wrapper。如需 iOS 验证，需要手动执行同步。

## 4. 本地运行到 iPhone

1. 打开 Xcode 工程：

   ```bash
   open /Users/lantian/Documents/合同审查/ios/HetongBang/HetongBang.xcodeproj
   ```

2. Scheme 选择 `HetongBang`。
3. 连接 iPhone 或选择模拟器。
4. 配置 Signing & Capabilities。
5. 点击 Run。

首次真机运行可能需要在 iPhone 设置中信任开发者证书。

## 5. iOS 连接 Dify 的正式方案

不要把 Dify Key 打包进 iOS App。

推荐正式链路：

```text
iOS WKWebView
  -> HTTPS 后端
  -> Dify API
```

开发/模拟器阶段可以用本机代理：

```text
http://127.0.0.1:8787/api/dify
```

真机测试如需访问本机代理，需要使用 Mac 局域网 IP，并确保手机和 Mac 在同一网络。但这只适合临时测试，不适合上线。

## 6. App Store 上架前技术检查

必须检查：

- Bundle ID 是否正式。
- App 名称是否为“契合”。
- 图标是否齐全。
- 启动页是否正常。
- WKWebView 是否能正常加载 H5。
- 键盘弹起是否遮挡输入框。
- 底部安全区是否正常。
- 文件上传是否可用。
- 合同生成是否可用。
- 合同审查是否可用。
- 复制、导出、继续追问是否可用。
- 弱网和超时提示是否可理解。
- 后端 HTTPS 证书是否有效。

## 7. App Store 上架前内容检查

必须准备：

- App Store 标题。
- 副标题。
- 简介。
- 关键词。
- App 图标。
- 商店截图。
- 隐私政策 URL。
- 用户协议 URL。
- 支持 URL 或支持邮箱。
- 审核账号或审核说明。

## 8. AI 和法律类风险说明

App 内和商店材料不应宣称：

- 替代律师。
- 自动生成结果具备法律效力。
- 审查结果百分百准确。
- 能保证合同没有风险。

建议说明：

- 本产品为 AI 辅助工具。
- 输出仅供参考。
- 重要合同建议咨询专业律师。
- 用户上传合同文本会用于生成和审查服务处理。

## 9. 隐私政策至少说明

隐私政策应覆盖：

- 收集哪些用户输入。
- 是否上传合同文本。
- 是否上传文件。
- 数据传给哪些服务。
- 是否保存历史。
- 本地历史和云历史的区别。
- 用户如何删除本地历史。
- 联系方式。

当前前端设置页显示“本地隐私模式”，但正式后端接入后，需要隐私政策与真实数据流一致。

## 10. TestFlight 建议

上架前建议先走 TestFlight：

1. 内测 5-10 人。
2. 覆盖 iPhone 小屏和大屏。
3. 覆盖 Wi-Fi 和移动网络。
4. 覆盖长合同输入。
5. 覆盖 PDF/DOCX 文件上传。
6. 覆盖 Dify 超时和失败。
7. 记录崩溃、白屏、卡死和生成异常。

## 11. iOS 交接结论

当前 iOS wrapper 已有基础工程，但还不是正式上架状态。正式上架前必须由 iOS/上线负责人完成签名、图标、隐私、后端域名、真机测试和 App Store Connect 配置。

