import SwiftUI

struct SubjectView: View {
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let result = historyStore.record(id: recordId)?.reviewPayload?.result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        QiheSectionHeader(
                            title: "识别信息",
                            subtitle: "展示甲方、乙方、金额、期限等合同要素。识别不到时使用空状态。"
                        )

                        SubjectFactsPanel(result: result)

                        PaperCard(padding: 14) {
                            VStack(spacing: 12) {
                                ProcessNode(
                                    title: "中文字段",
                                    detail: "仅展示甲方、乙方、合同类型、金额、期限、司法辖区。",
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
