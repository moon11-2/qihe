# 契合

`契合` 是一款面向 iPhone 的 AI 合同审查与合同生成助手。

当前主线实现位于 `qihe/`：FastAPI 后端 + SwiftUI iOS App，已经具备合同审查、合同生成、文件上传解析、Word 导出和本地历史等 MVP 闭环。

远端仓库历史中还保留了早期 uni-app / Dify 原型，位于根目录的 `src/`、`ios/HetongBang/`、`docs/` 等路径，可作为设计与交接资料归档参考。

## 主线目录

```txt
qihe/
  backend/   FastAPI 后端
  ios/       SwiftUI iPhone App
  docs/      分工、原则、验收与参考文档
```

## 后端本地启动

如果仓库位于 Documents、iCloud Drive 或其他同步目录，推荐把虚拟环境放到 `/tmp`：

```bash
cd qihe/backend
python3 -m venv /tmp/qihe-backend-venv
source /tmp/qihe-backend-venv/bin/activate
python -m pip install -U pip
python -m pip install -e ".[dev]"
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

健康检查：

```bash
curl http://127.0.0.1:8000/api/health
```

## iOS 本地构建

```bash
cd qihe/ios
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

## 早期 uni-app 原型

远端原型可用以下方式启动：

```bash
npm install
npm run dev:h5 -- --host 127.0.0.1
```

打开：

```text
http://127.0.0.1:5173/
```

真实 Dify token、cookie、API key 只放本地环境文件，不要提交到仓库。

## 协作入口

- 开发分工、原则、验收：[qihe/docs/development_framework.md](qihe/docs/development_framework.md)
- 原始设计与开发文档：[qihe/docs/reference](qihe/docs/reference)
- 后端说明：[qihe/backend/README.md](qihe/backend/README.md)
- iOS 说明：[qihe/ios/README.md](qihe/ios/README.md)
- 早期 Dify 输出契约：[docs/dify-output-contract.md](docs/dify-output-contract.md)
- 早期 iOS wrapper 说明：[docs/ios-xcode-run.md](docs/ios-xcode-run.md)
