import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GenerateResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID
    @State private var isExporting = false
    @State private var shareDocument: ShareDocument?
    @State private var errorMessage: String?
    @State private var didCopy = false

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let payload = historyStore.record(id: recordId)?.generatePayload {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let errorMessage {
                            ErrorBanner(message: errorMessage, retryTitle: "重试导出") {
                                Task {
                                    await exportWord(payload)
                                }
                            }
                        }

                        header(payload)
                        draft(payload.result)
                        missingFields(payload.result)
                        checklist(payload.result)
                    }
                    .padding(20)
                }
            } else {
                EmptyStateView(
                    title: "无法读取生成结果",
                    detail: "这条历史可能已经被清空。"
                )
                .padding(24)
            }
        }
        .navigationTitle("生成结果")
        .qiheInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .qiheTopTrailing) {
                Button {
                    if let payload = historyStore.record(id: recordId)?.generatePayload {
                        Task {
                            await exportWord(payload)
                        }
                    }
                } label: {
                    Image(systemName: isExporting ? "hourglass" : "square.and.arrow.up")
                }
                .foregroundStyle(QiheColor.navy)
                .disabled(historyStore.record(id: recordId)?.generatePayload == nil || isExporting)
                .accessibilityLabel("导出 Word")
            }
        }
        .sheet(item: $shareDocument) { document in
            ShareSheet(document: document)
        }
    }

    private func header(_ payload: GenerateHistoryPayload) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    SealMark(size: 38)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(payload.result.displayTitle)
                            .font(QiheFont.title(size: 24))
                            .foregroundStyle(QiheColor.ink)

                        Text("草案生成后，请补齐字段并完成签署前核对。")
                            .font(QiheFont.caption())
                            .foregroundStyle(QiheColor.muted)
                    }

                    Spacer()
                }

                HStack(spacing: 10) {
                    QiheSecondaryButton(
                        title: didCopy ? "已复制" : "复制草案",
                        systemImage: didCopy ? "checkmark" : "doc.on.doc"
                    ) {
                        copyDraft(payload.result.draft ?? "")
                        didCopy = true
                    }

                    QiheSecondaryButton(title: "继续修改", systemImage: "square.and.pencil") {
                        appState.path.append(.generate(prefill: payload.result.draft ?? payload.requestText))
                    }
                }
            }
        }
    }

    private func draft(_ result: GenerateResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "合同草案", subtitle: result.source?.filename)

            PaperCard {
                Text(result.draft?.nilIfBlank ?? "暂无合同草案。")
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(QiheColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func missingFields(_ result: GenerateResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "待补充字段", subtitle: "\(result.fieldsToComplete.count) 项")

            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    if result.fieldsToComplete.isEmpty {
                        Text("暂无待补充字段。")
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.muted)
                    } else {
                        ForEach(result.fieldsToComplete, id: \.self) { field in
                            ResultLine(systemImage: "square.and.pencil", text: field)
                        }
                    }
                }
            }
        }
    }

    private func checklist(_ result: GenerateResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "签署前清单", subtitle: "\(result.checklist.count) 项")

            PaperCard {
                VStack(alignment: .leading, spacing: 10) {
                    if result.checklist.isEmpty {
                        Text("暂无签署前清单。")
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.muted)
                    } else {
                        ForEach(result.checklist, id: \.self) { item in
                            ResultLine(systemImage: "checkmark.seal", text: item)
                        }
                    }
                }
            }
        }
    }

    private func exportWord(_ payload: GenerateHistoryPayload) async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let url = try await appState.apiClient.exportGenerateWord(
                title: payload.result.displayTitle,
                payload: payload.result
            )
            shareDocument = ShareDocument(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyDraft(_ value: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

private struct ResultLine: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.navy)
                .frame(width: 20)

            Text(text)
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
