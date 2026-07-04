# 合同帮前端接入说明

## 当前接入方式

前端已经接入统一服务层：

- 默认 `VITE_DIFY_ENABLED=false`，使用本地 Mock 返回，方便无密钥时验收界面。
- 配置 Dify 后，H5 开发环境通过 Vite 代理请求 Dify API，避免把 Dify App API Key 暴露到浏览器代码里。

相关文件：

- `/Users/lantian/Documents/合同审查/src/services/dify.ts`
- `/Users/lantian/Documents/合同审查/vite.config.ts`
- `/Users/lantian/Documents/合同审查/.env.example`

## 本地 H5 模拟

```bash
cd /Users/lantian/Documents/合同审查
npm run dev:h5 -- --host 127.0.0.1
```

访问：

```text
http://127.0.0.1:5173/
```

不需要先安装 iOS 模拟器。H5 足够用于检查主要交互、结果渲染、记录页和设置页。

## 真实 Dify 接入

在本机创建 `.env.local`，不要提交：

```env
DIFY_API_BASE_URL=https://api.dify.ai/v1
DIFY_API_KEY=你的 Dify App API Key
VITE_DIFY_ENABLED=true
VITE_DIFY_PROXY_PATH=/api/dify
```

然后重启 H5 开发服务器。

## 内测封装建议

1. H5 原型验收通过后，再做真实 Dify 接入联调。
2. iOS 模拟器/真机内测阶段需要 HBuilderX、Xcode 和 Apple 开发者相关配置。
3. 正式内测不建议把 Dify API Key 打进 App 包，应使用自己的后端代理或云函数转发。
