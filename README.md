# 契合

`契合` 是一款面向 iPhone 的 AI 合同审查与合同生成助手。

当前仓库就是正式主线：FastAPI 后端 + SwiftUI iOS App，已经具备合同审查、合同生成、文件上传解析、Word 导出和本地历史等 MVP 闭环。

## 主线目录

```txt
backend/   FastAPI 后端
ios/       SwiftUI iPhone App
docs/      分工、原则、验收与参考文档
```

## 后端本地启动

如果仓库位于 Documents、iCloud Drive 或其他同步目录，推荐把虚拟环境放到 `/tmp`：

```bash
cd backend
python3 -m venv /tmp/qihe-backend-venv
source /tmp/qihe-backend-venv/bin/activate
python -m pip install -U pip
python -m pip install -e ".[dev]"
uvicorn app.main:app --host 127.0.0.1 --port 8010
```

健康检查：

```bash
curl http://127.0.0.1:8010/api/health
```

## iOS 本地构建

```bash
cd ios
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build --scratch-path /tmp/qihe-swiftpm-build
```

正式 Xcode App target 建议从非同步目录或 `/tmp` 副本构建，避免 Documents/iCloud 的文件协调锁影响 Xcode：

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Qihe.xcodeproj \
  -scheme Qihe \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.4' \
  -derivedDataPath /tmp/qihe-AppDerivedData \
  build
```

真实模型密钥、cookie、API key 只放本地环境文件，不要提交到仓库。

iOS App 默认连接正式后端 `https://api.qihe1.xyz`。本地联调时可在 Xcode Scheme 或运行环境里把 `QIHE_API_BASE_URL` 临时覆盖为 `http://127.0.0.1:8010`。更多 iOS 运行配置见 [ios/README.md](ios/README.md)。

## 协作入口

- 开发分工、原则、验收：[docs/development_framework.md](docs/development_framework.md)
- 原始设计与开发文档：[docs/reference](docs/reference)
- 后端说明：[backend/README.md](backend/README.md)
- iOS 说明：[ios/README.md](ios/README.md)
