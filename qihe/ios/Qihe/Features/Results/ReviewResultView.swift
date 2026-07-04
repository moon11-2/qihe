import SwiftUI

struct ReviewResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID
    @State private var isExporting = false
    @State private var shareDocument: ShareDocument?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let payload = historyStore.record(id: recordId)?.reviewPayload {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let errorMessage {
                            ErrorBanner(message: errorMessage, retryTitle: "重试导出") {
                                Task {
                                    await exportWord(payload)
                                }
                            }
                        }

                        header(payload.result)
                        originalText(payload)
                        riskList(payload.result)
                        parties(payload.result)
                    }
                    .padding(20)
                }
            } else {
                EmptyStateView(
                    title: "无法读取审查结果",
                    detail: "这条历史可能已经被清空。"
                )
                .padding(24)
            }
        }
        .navigationTitle("审查结果")
        .qiheInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .qiheTopTrailing) {
                Button {
                    if let payload = historyStore.record(id: recordId)?.reviewPayload {
                        Task {
                            await exportWord(payload)
                        }
                    }
                } label: {
                    Image(systemName: isExporting ? "hourglass" : "square.and.arrow.up")
                }
                .foregroundStyle(QiheColor.navy)
                .disabled(historyStore.record(id: recordId)?.reviewPayload == nil || isExporting)
                .accessibilityLabel("导出 Word")
            }
        }
        .sheet(item: $shareDocument) { document in
            ShareSheet(document: document)
        }
    }

    private func header(_ result: ReviewResult) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(result.displayTitle)
                            .font(QiheFont.title(size: 24))
                            .foregroundStyle(QiheColor.ink)

                        Text(result.reviewBasis?.nilIfBlank ?? "审查基准以服务端返回为准。")
                            .font(QiheFont.caption())
                            .foregroundStyle(QiheColor.muted)
                    }

                    Spacer()

                    QiheStatusPill(
                        text: (result.riskLevel ?? .pending).label,
                        color: (result.riskLevel ?? .pending).foreground,
                        background: (result.riskLevel ?? .pending).background
                    )
                }

                if let summary = result.summary?.nilIfBlank {
                    LabeledText(label: "摘要", text: summary)
                }

                if let score = result.score {
                    LabeledText(label: "评分", text: "\(score)")
                }
            }
        }
    }

    private func originalText(_ payload: ReviewHistoryPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "原文", subtitle: payload.attachment?.filename)

            PaperCard {
                Text(payload.result.sourceText)
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(QiheColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func riskList(_ result: ReviewResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "风险", subtitle: "\(result.risks.count) 项")

            if result.risks.isEmpty {
                PaperCard {
                    EmptyStateView(
                        title: "暂无风险条目",
                        detail: "后端未返回风险列表时，会保留摘要和原文。"
                    )
                }
            } else {
                ForEach(result.risks) { risk in
                    RiskCard(risk: risk)
                }
            }
        }
    }

    private func parties(_ result: ReviewResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "主体", subtitle: "合同当事人与关键信息")

            PaperCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(result.parties?.displayString ?? "暂无主体信息。")
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)

                    QiheSecondaryButton(title: "查看主体详情", systemImage: "person.text.rectangle") {
                        appState.path.append(.subject(recordId: recordId))
                    }
                }
            }
        }
    }

    private func exportWord(_ payload: ReviewHistoryPayload) async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let url = try await appState.apiClient.exportReviewWord(
                title: payload.result.displayTitle,
                payload: payload.result
            )
            shareDocument = ShareDocument(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
