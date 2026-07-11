import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GenerateResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var revisionStore: RevisionStore
    let recordId: UUID
    @State private var currentDraft: String?
    @State private var fieldValues: [String: String] = [:]
    @State private var editedParagraphIds: Set<String> = []
    @State private var scrollToSegmentId: String? = nil
    @State private var isExporting = false
    @State private var shareDocument: ShareDocument?
    @State private var errorMessage: String?
    @State private var didCopy = false
    @State private var showLocateDialog = false

    var body: some View {
        ZStack {
            QiheColor.pageBackgroundGradient.ignoresSafeArea()

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

                        contractEditorSheet(payload)
                        checklist(payload.result)
                        actions(payload)

                        Text("AI 辅助起草，不构成法律意见")
                            .font(QiheFont.caption(size: 11))
                            .foregroundStyle(QiheColor.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
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
        .task {
            // 任务三：视图出现时从后端拉取 revisions 并合并到本地缓存
            _ = await revisionStore.fetchAndMergeRevisions(recordId: recordId)
        }
    }

    private func contractEditorSheet(_ payload: GenerateHistoryPayload) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            generateHeader(payload)
            generateStats(payload.result)
            contractPaper(payload)
            placeholderTokenList(payload.result)
        }
    }

    private func generateHeader(_ payload: GenerateHistoryPayload) -> some View {
        HStack(alignment: .center, spacing: 12) {
            QiheLogoMark(size: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(payload.result.displayTitle)
                    .font(QiheFont.title(size: 18))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(payload.attachment?.filename ?? "契合起草 · 参照《民法典》合同编体例")
                    .font(QiheFont.caption(size: 11))
                    .foregroundStyle(QiheColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 8)

            QiheStatusPill(
                text: "待填写 \(unfilledPlaceholderCount(in: payload.result))",
                color: unfilledPlaceholderCount(in: payload.result) > 0 ? QiheColor.riskOrange : QiheColor.safeGreen,
                background: unfilledPlaceholderCount(in: payload.result) > 0 ? QiheColor.riskOrangeSoft : QiheColor.safeGreenSoft
            )
        }
        .padding(14)
        .background(QiheColor.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                .stroke(QiheColor.glassStroke, lineWidth: 1)
        )
    }

    private func generateStats(_ result: GenerateResult) -> some View {
        ResultStatStrip(
            items: [
                ResultStatItem(label: "待填写", value: "\(unfilledPlaceholderCount(in: result))", color: QiheColor.riskOrange),
                ResultStatItem(label: "已填写", value: "\(filledPlaceholderCount(in: result))", color: QiheColor.safeGreen),
                ResultStatItem(label: "已修改", value: "\(editedParagraphIds.count)", color: QiheColor.brandBlue)
            ]
        )
    }

    private func contractPaper(_ payload: GenerateHistoryPayload) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(spacing: 5) {
                Text(payload.result.displayTitle)
                    .font(QiheFont.title(size: 20))
                    .foregroundStyle(QiheColor.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: .infinity)

                Text("草案 · 契合起草 · 参照《民法典》合同编体例")
                    .font(QiheFont.caption(size: 10, weight: .medium))
                    .foregroundStyle(QiheColor.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
            }

            GeneratedContractEditorView(
                draft: payload.result.draft ?? "",
                preParsedSegments: generateSegments(from: payload),
                fieldValues: $fieldValues,
                editedParagraphIds: $editedParagraphIds,
                scrollToSegmentId: $scrollToSegmentId,
                onDraftChange: { draft in
                    currentDraft = draft
                    didCopy = false
                }
            )
            .frame(minHeight: 260)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 22)
        .background(QiheColor.card.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                .stroke(QiheColor.glassStroke, lineWidth: 1)
        )
        .shadow(color: QiheColor.shadowNavySoft, radius: 12, x: 0, y: 4)
    }

    /// 生成合同的段落解析：优先后端 blocks，回退前端分段
    private func generateSegments(from payload: GenerateHistoryPayload) -> [DocumentSegment]? {
        guard payload.result.hasBackendBlocks else { return nil }
        // 任务三：从 RevisionStore 恢复已确认的修改状态
        let confirmedStates = revisionStore.confirmedBlockStates(for: recordId)
        return DraftSegmentParser.parseGenerate(
            blocks: payload.result.blocks,
            draft: payload.result.draft,
            revisionStates: confirmedStates
        )
    }

    private func placeholderTokenList(_ result: GenerateResult) -> some View {
        let names = fieldNames(for: result)

        return Group {
            if !names.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("待填写占位符")
                            .font(QiheFont.title(size: 16))
                            .foregroundStyle(QiheColor.ink)

                        Spacer(minLength: 8)

                        QiheStatusPill(
                            text: "\(filledPlaceholderCount(in: result))/\(names.count) 已填",
                            color: unfilledPlaceholderCount(in: result) > 0 ? QiheColor.riskOrange : QiheColor.safeGreen,
                            background: unfilledPlaceholderCount(in: result) > 0 ? QiheColor.riskOrangeSoft : QiheColor.safeGreenSoft
                        )
                    }

                    VStack(spacing: 0) {
                        ForEach(names, id: \.self) { name in
                            placeholderTokenRow(name: name)

                            if name != names.last {
                                Rectangle()
                                    .fill(QiheColor.line.opacity(0.85))
                                    .frame(height: 1)
                            }
                        }
                    }
                }
                .padding(14)
                .background(QiheColor.glassFill)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                        .stroke(QiheColor.glassStroke, lineWidth: 1)
                )
                .shadow(color: QiheColor.shadowNavySoft, radius: 8, x: 0, y: 2)
            }
        }
    }

    private func placeholderTokenRow(name: String) -> some View {
        let value = fieldValues[name]?.nilIfBlank
        let isFilled = value != nil

        return HStack(spacing: 10) {
            Circle()
                .fill(isFilled ? QiheColor.safeGreen : QiheColor.riskOrange)
                .frame(width: 8, height: 8)

            Text(name)
                .font(QiheFont.body(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer(minLength: 8)

            Text(value ?? "未填写")
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(isFilled ? QiheColor.safeGreen : QiheColor.riskOrange)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Image(systemName: isFilled ? "checkmark" : "square.and.pencil")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isFilled ? QiheColor.safeGreen : QiheColor.riskOrange)
                .frame(width: 24, height: 24)
                .background(isFilled ? QiheColor.safeGreenSoft : QiheColor.riskOrangeSoft)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))
        }
        .padding(.vertical, 9)
    }

    private func filledPlaceholderCount(in result: GenerateResult) -> Int {
        fieldNames(for: result).filter { fieldValues[$0]?.nilIfBlank != nil }.count
    }

    private func unfilledPlaceholderCount(in result: GenerateResult) -> Int {
        fieldNames(for: result).filter { fieldValues[$0]?.nilIfBlank == nil }.count
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
        let columns = [
            GridItem(.adaptive(minimum: 136), spacing: 10)
        ]

        return LazyVGrid(columns: columns, spacing: 10) {
            QiheSecondaryButton(
                title: didCopy ? "已复制" : "复制全文",
                systemImage: didCopy ? "checkmark" : "doc.on.doc"
            ) {
                copyDraft(activeDraft(for: payload.result))
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

            QiheSecondaryButton(title: "定位", systemImage: "location.magnifyingglass") {
                showLocateDialog = true
            }

            QihePrimaryButton(title: "继续修改", systemImage: "square.and.pencil") {
                guard requireSignIn() else {
                    return
                }
                appState.path.append(
                    .generate(
                        prefill: activeDraft(for: payload.result),
                        sourceChatRecordId: payload.sourceChatRecordId
                    )
                )
            }
        }
        .confirmationDialog("定位到未填项", isPresented: $showLocateDialog, titleVisibility: .visible) {
            let unfilledPlaceholders = placeholders(in: payload.result.draft ?? "")
                .filter { fieldValues[$0]?.nilIfBlank == nil }

            if unfilledPlaceholders.isEmpty {
                Button("所有占位符已填写完毕") {}
            } else {
                ForEach(unfilledPlaceholders, id: \.self) { name in
                    Button(name) {
                        let parsed = DraftSegmentParser.parse(payload.result.draft ?? "")
                        if let target = parsed.first(where: { segment in
                            if case .placeholder(let n) = segment.kind, n == name {
                                return true
                            }
                            return false
                        }) {
                            scrollToSegmentId = target.id
                        }
                    }
                }
            }

            Button("取消", role: .cancel) {}
        } message: {
            let unfilledCount = placeholders(in: payload.result.draft ?? "")
                .filter { fieldValues[$0]?.nilIfBlank == nil }
                .count
            if unfilledCount > 0 {
                Text("还有 \(unfilledCount) 个占位符未填写")
            } else {
                Text("所有占位符已填写完毕")
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

    private func activeDraft(for result: GenerateResult) -> String {
        if let currentDraft {
            return currentDraft
        }

        if result.hasBackendBlocks {
            return result.blocks?.map(\.text).joined(separator: "\n\n") ?? result.draft ?? ""
        }
        return result.draft ?? ""
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
        guard authStore.status.isSignedIn else {
            await MainActor.run {
                openSignIn()
            }
            return
        }
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            var result = payload.result
            result.draft = activeDraft(for: payload.result)
            result.blocks = nil
            let url = try await appState.apiClient.exportGenerateWord(
                title: result.displayTitle,
                payload: result
            )
            shareDocument = ShareDocument(url: url)
        } catch {
            errorMessage = error.qiheDisplayMessage
        }
    }

    @MainActor
    private func requireSignIn() -> Bool {
        guard authStore.status.isSignedIn else {
            openSignIn()
            return false
        }
        return true
    }

    @MainActor
    private func openSignIn() {
        authStore.requestSignIn()
        appState.selectedTab = .profile
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
