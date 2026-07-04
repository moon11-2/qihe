import SwiftUI

struct SubjectView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let payload = historyStore.record(id: recordId)?.reviewPayload {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        QiheSectionHeader(
                            title: "主体信息",
                            subtitle: payload.attachment?.filename ?? payload.result.displayTitle
                        )

                        PaperCard {
                            VStack(alignment: .leading, spacing: 14) {
                                LabeledText(
                                    label: "来源",
                                    text: payload.result.source?.filename
                                        ?? payload.attachment?.filename
                                        ?? "文本输入"
                                )

                                LabeledText(
                                    label: "主体",
                                    text: payload.result.parties?.displayString ?? "暂无主体信息。"
                                )
                            }
                        }

                        PaperCard {
                            VStack(spacing: 12) {
                                ProcessNode(
                                    title: "仅展示审查结果",
                                    detail: "主体信息来自合同审查返回内容，仅用于核对展示。",
                                    isDone: true
                                )
                                ProcessNode(
                                    title: "本地可恢复",
                                    detail: "断网时仍可从本机历史打开这一页。",
                                    isActive: true
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                EmptyStateView(
                    title: "无法读取主体信息",
                    detail: "这条历史可能已经被清空。"
                )
                .padding(24)
            }
        }
        .navigationTitle("主体")
        .qiheInlineNavigationTitle()
    }
}
