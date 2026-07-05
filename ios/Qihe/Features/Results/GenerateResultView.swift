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
    @State private var fieldValues: [String: String] = [:]
    @State private var isExporting = false
    @State private var shareDocument: ShareDocument?
    @State private var errorMessage: String?
    @State private var didCopy = false

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let payload = historyStore.record(id: recordId)?.generatePayload {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let errorMessage {
                            ErrorBanner(message: errorMessage, retryTitle: "重试导出") {
                                Task {
                                    await exportWord(payload)
                                }
                            }
                        }

                        contractSheet(payload)
                        missingFieldsForm(payload)
                        checklist(payload.result)
                        actions(payload)

                        Text("AI 辅助起草，不构成法律意见")
                            .font(QiheFont.caption(size: 11))
                            .foregroundStyle(QiheColor.muted)
                            .frame(maxWidth: .infinity)
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
        .navigationTitle("合同草案")
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

    private func contractSheet(_ payload: GenerateHistoryPayload) -> some View {
        let draft = renderedDraft(payload.result)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                SealMark(size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(payload.result.displayTitle)
                        .font(QiheFont.title(size: 16))
                        .foregroundStyle(QiheColor.ink)
                    Text(payload.attachment?.filename ?? "契合起草 · 参照《民法典》合同编体例")
                        .font(QiheFont.caption(size: 11))
                        .foregroundStyle(QiheColor.muted)
                }
                Spacer()
            }

            VStack(spacing: 12) {
                Text(payload.result.displayTitle)
                    .font(QiheFont.title(size: 19))
                    .foregroundStyle(QiheColor.ink)
                    .frame(maxWidth: .infinity)

                Text("草案 · 契合起草 · 参照《民法典》合同编体例")
                    .font(QiheFont.caption(size: 10))
                    .foregroundStyle(QiheColor.muted)
                    .frame(maxWidth: .infinity)

                Text(draft.nilIfBlank ?? "暂无合同草案。")
                    .font(QiheFont.document(size: 13))
                    .foregroundStyle(QiheColor.inkSoft)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .background(QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                    .stroke(QiheColor.lineStrong, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                    .stroke(QiheColor.line, lineWidth: 1)
                    .padding(6)
            )
            .overlay(alignment: .bottomTrailing) {
                Text("待簽\n用印")
                    .font(QiheFont.title(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(QiheColor.seal.opacity(0.58))
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                            .stroke(QiheColor.seal.opacity(0.48), lineWidth: 2.5)
                    )
                    .rotationEffect(.degrees(-7))
                    .padding(14)
            }
        }
    }

    private func missingFieldsForm(_ payload: GenerateHistoryPayload) -> some View {
        let fields = fieldNames(for: payload.result)
        return PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("待补充信息")
                    .font(QiheFont.title(size: 14))
                    .foregroundStyle(QiheColor.ink)

                if fields.isEmpty {
                    Text("暂无待补充字段。")
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.muted)
                } else {
                    ForEach(fields, id: \.self) { field in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(field)
                                .font(QiheFont.caption(size: 12, weight: .semibold))
                                .foregroundStyle(QiheColor.seal)

                            TextField("填写\(field)", text: binding(for: field))
                                .font(QiheFont.body(size: 14))
                                .foregroundStyle(QiheColor.ink)
                                .padding(.horizontal, 10)
                                .frame(height: 38)
                                .background(QiheColor.paper)
                                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                                        .stroke(QiheColor.line, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
    }

    private func checklist(_ result: GenerateResult) -> some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("签署前清单")
                    .font(QiheFont.title(size: 14))
                    .foregroundStyle(QiheColor.ink)

                if result.checklist.isEmpty {
                    Text("暂无签署前清单。")
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.muted)
                } else {
                    ForEach(result.checklist, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(QiheColor.muted, lineWidth: 1.4)
                                .frame(width: 14, height: 14)
                                .padding(.top, 3)

                            Text(item)
                                .font(QiheFont.body(size: 12.5))
                                .foregroundStyle(QiheColor.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private func actions(_ payload: GenerateHistoryPayload) -> some View {
        HStack(spacing: 10) {
            QiheSecondaryButton(
                title: didCopy ? "已复制" : "复制全文",
                systemImage: didCopy ? "checkmark" : "doc.on.doc"
            ) {
                copyDraft(renderedDraft(payload.result))
                didCopy = true
            }

            QiheSecondaryButton(
                title: isExporting ? "导出中" : "导出",
                systemImage: "square.and.arrow.up",
                isDisabled: isExporting
            ) {
                Task {
                    await exportWord(payload)
                }
            }

            QihePrimaryButton(title: "继续修改", systemImage: "square.and.pencil") {
                appState.path.append(.generate(prefill: renderedDraft(payload.result)))
            }
        }
    }

    private func binding(for field: String) -> Binding<String> {
        Binding(
            get: { fieldValues[field, default: ""] },
            set: { fieldValues[field] = $0 }
        )
    }

    private func fieldNames(for result: GenerateResult) -> [String] {
        var names: [String] = []
        for field in result.fieldsToComplete {
            appendUnique(field, to: &names)
        }
        for field in placeholders(in: result.draft ?? "") {
            appendUnique(field, to: &names)
        }
        return names
    }

    private func renderedDraft(_ result: GenerateResult) -> String {
        var draft = result.draft ?? ""
        for field in fieldNames(for: result) {
            guard let value = fieldValues[field]?.nilIfBlank else {
                continue
            }
            let tokens = [
                "【待补充：\(field)】",
                "【待补充:\(field)】",
                "[\(field)]"
            ]
            for token in tokens {
                draft = draft.replacingOccurrences(of: token, with: value)
            }
        }
        return draft
    }

    private func placeholders(in draft: String) -> [String] {
        var values: [String] = []
        let patterns = [
            #"【待补充[:：]([^】]+)】"#,
            #"\[([^\]\n]{1,40})\]"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }
            let nsRange = NSRange(draft.startIndex..<draft.endIndex, in: draft)
            let matches = regex.matches(in: draft, range: nsRange)
            for match in matches where match.numberOfRanges > 1 {
                guard let range = Range(match.range(at: 1), in: draft) else {
                    continue
                }
                appendUnique(String(draft[range]), to: &values)
            }
        }
        return values
    }

    private func appendUnique(_ value: String, to values: inout [String]) {
        guard let cleaned = value.nilIfBlank, !values.contains(cleaned) else {
            return
        }
        values.append(cleaned)
    }

    private func exportWord(_ payload: GenerateHistoryPayload) async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            var result = payload.result
            result.draft = renderedDraft(payload.result)
            let url = try await appState.apiClient.exportGenerateWord(
                title: result.displayTitle,
                payload: result
            )
            shareDocument = ShareDocument(url: url)
        } catch {
            errorMessage = error.qiheDisplayMessage
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
