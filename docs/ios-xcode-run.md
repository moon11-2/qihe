# iPhone 真机试用说明

当前 iOS 工程是一个轻量 Xcode 壳：

- SwiftUI App
- `WKWebView`
- 内置 `dist/build/h5` 生成的静态 WebApp
- 默认 Mock 模式，可离线试原型交互

## 工程位置

```text
/Users/lantian/Documents/合同审查/ios/HetongBang/HetongBang.xcodeproj
```

## 每次更新前端后同步到 Xcode

```bash
cd /Users/lantian/Documents/合同审查
./scripts/sync-ios-webapp.sh
```

这个脚本会执行：

1. `npm run build:h5`
2. 删除旧的 `ios/HetongBang/HetongBang/WebApp`
3. 复制最新 H5 静态产物到 Xcode 工程

## 安装到 iPhone

1. 用 USB 连接 iPhone，并在手机上点“信任此电脑”。
2. 打开：

   ```bash
   open /Users/lantian/Documents/合同审查/ios/HetongBang/HetongBang.xcodeproj
   ```

3. Xcode 顶部 Scheme 选择 `HetongBang`。
4. 运行目标选择你的 iPhone。
5. 打开 target `HetongBang` 的 `Signing & Capabilities`。
6. 勾选 `Automatically manage signing`。
7. Team 选择你的 Apple ID / 开发者账号。
8. 如果 Bundle Identifier 冲突，把 `com.nightlt7.hetongbang` 改成唯一值，例如 `com.nightlt7.hetongbang.dev`。
9. 点击 Run。

如果手机第一次运行个人开发者签名 App，可能需要在 iPhone：

```text
设置 -> 通用 -> VPN 与设备管理
```

信任你的开发者证书。

## 当前限制

- 默认同步脚本生成 Mock 模式，用于检查交互和视觉。
- 模拟器可通过本机代理连接真实 Dify，不会把 Dify API Key 打进前端 JS。
- 真机真实 Dify 调用建议使用后端代理或云函数；临时测试可把代理地址改成 Mac 局域网 IP。

## 模拟器连接真实 Dify

1. 在 `.env.local` 填入你的 Dify App API Key：

   ```env
   DIFY_API_BASE_URL=https://api.dify.ai/v1
   DIFY_API_KEY=你的 Dify App API Key
   VITE_DIFY_ENABLED=true
   VITE_DIFY_PROXY_PATH=/api/dify
   DIFY_PROXY_PORT=8787
   ```

2. 启动本机 Dify 代理：

   ```bash
   cd /Users/lantian/Documents/合同审查
   npm run dify:proxy
   ```

3. 另开一个终端，同步 Dify 模式的 iOS WebApp：

   ```bash
   cd /Users/lantian/Documents/合同审查
   npm run sync:ios:dify
   ```

4. 在 Xcode 里重新运行 `HetongBang` 到模拟器。

此模式下 App 请求 `http://127.0.0.1:8787/api/dify`，由本机代理加上 Authorization 后转发给 Dify。
