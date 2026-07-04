# 契合前端上架前巡检记录

日期：2026-07-04

范围：390px iPhone 宽度下的主页、功能页、合同审查、合同生成、合同类型抽屉、主页 Dify 闲聊、主页审查/生成分流、空表单校验、结果页、历史、设置。

## 已修复

1. 任务页空表单提交后，错误提示原本可能落在当前视口之外。现在改为固定在底部主按钮上方，并保留复制/关闭操作。
2. 设置页“登录”是未接入的死入口。现在改为不可点击的“本地使用”状态标识。
3. 设置页原本直接展示 Mock / Dify 工程术语。现在改为“演示服务 / 在线服务”等用户可理解文案。
4. 设置页占位入口只显示 toast，容易被审核和用户视为未完成内容。现在移除未接入的占位入口，只保留真实可用设置和清空历史。
5. 处理任务时增加最短展示时间和一帧绘制等待，避免响应过快时用户几乎看不到处理中状态。
6. 主页在线模式改为先请求 Dify 判断意图；闲聊保留在聊天流，显示“正在理解你的问题”动态气泡。
7. 主页识别到合同审查或合同生成，统一进入功能页同款处理浮层；Dify 返回完整结果时直接进入审查/生成结果页，不再重复二次执行。
8. Dify 联调字段修正：`output_style` 固定传工作流可识别的“普通用户可读”，输出详略偏好改放入 `requirements`；房屋租赁类型统一为“房屋租赁合同”。

## 验证截图

- `01-home.png`
- `04-review-expanded-empty.png`
- `05-generate-expanded-empty.png`
- `06-contract-type-drawer.png`
- `09-generate-result.png`
- `10-history.png`
- `12-generate-validation-fixed.png`
- `14-settings-final.png`
- `qihe-home-chat-thinking-390.png`
- `qihe-home-online-review-processing-390.png`
- `qihe-home-online-review-result-390.png`
- `qihe-home-online-generate-processing-390.png`
- `qihe-home-online-generate-result-390.png`
- `appstore-frontend-audit/01-home-empty.png`
- `appstore-frontend-audit/04-features-review-filled.png`
- `appstore-frontend-audit/06-features-generate-filled.png`
- `appstore-frontend-audit/09-contract-type-selected.png`
- `appstore-frontend-audit/11-history-empty.png`
- `appstore-frontend-audit/15-settings-clean.png`

## 2026-07-04 收尾巡检

- `npm run type-check`：通过。
- `npm run build:h5`：通过。
- 当前 H5 dev server 注入：`VITE_DIFY_ENABLED=true`，`VITE_DIFY_PROXY_PATH=http://127.0.0.1:8787/api/dify`。
- Playwright 390px 巡检主页、功能页、审查/生成工作台、合同类型抽屉、历史、设置：未发现控制台错误或页面异常。
- 主页闲聊、主页合同生成、主页合同审查均已用真实 Dify 请求验证；闲聊留在聊天流，审查/生成进入对应进度浮层和结果页。
- 设置页底部入口可滚动访问；固定底部 Tab 未阻断操作。

## 当前判断

前端交互和视觉层面已经可以进入整理交接阶段。上架前仍需在真机 WKWebView 上复测文件上传、隐私说明、错误兜底、在线服务超时、App Store 隐私信息和支持/隐私政策链接。
