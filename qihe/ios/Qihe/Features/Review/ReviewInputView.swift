import SwiftUI

struct ReviewInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var extraInfo = ""
    @State private var attachment: UploadedFile?
    @State private var isFileImporterPresented = false
    @State private var isUploading = false
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var lastImportedURL: URL?

    init(prefill: String?, initialAttachment: UploadedFile? = nil) {
        _text = State(initialValue: prefill ?? "")
        _attachment = State(initialValue: initialAttachment)
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    formTitle

                    if let errorMessage {
                        ErrorBanner(message: errorMessage, retryTitle: retryTitle) {
                            retry()
                        }
                    }

                    textInput
                    uploadSlot

                    if shouldPreferText {
                        priorityNotice
                    }

                    PaperCard(padding: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("更多信息")
                                    .font(QiheFont.body(size: 14, weight: .semibold))
                                    .foregroundStyle(QiheColor.ink)

                                QiheStatusPill(
                                    text: "可选",
                                    color: QiheColor.muted,
                                    background: QiheColor.paperDeep
                                )
                            }

                            TextField("合同类型、我的立场、关注重点", text: $extraInfo, axis: .vertical)
                                .font(QiheFont.body(size: 14))
                                .foregroundStyle(QiheColor.inkSoft)
                                .lineLimit(1...3)
                                .disabled(isRunning)
                        }
                    }

                    PaperCard(padding: 14) {
                        VStack(spacing: 12) {
                            ProcessNode(
                                title: "解析文本",
                                detail: hasText ? "将优先按粘贴文本审查。" : "可粘贴合同全文，或上传文件。",
                                isDone: hasText
                            )
                            ProcessNode(
                                title: "识别主体",
                                detail: attachment == nil ? "上传文件后可辅助识别合同来源。" : "已上传 \(attachment?.filename ?? "合同文件")。",
                                isDone: attachment != nil
                            )
                            ProcessNode(
                                title: "条款比对",
                                detail: "提交后生成风险、法条依据与修订建议。",
                                isActive: isRunning
                            )
                            ProcessNode(
                                title: "出具报告",
                                detail: "结果页默认进入风险报告。",
                                isDone: false
                            )
                        }
                    }

                    QihePrimaryButton(
                        title: "开始审查",
                        systemImage: "doc.text.magnifyingglass",
                        isLoading: isRunning,
                        isDisabled: !hasInput || isUploading
                    ) {
                        Task {
                            await runReview()
                        }
                    }

                    Text("AI 辅助审查，不构成法律意见")
                        .font(QiheFont.caption(size: 11))
                        .foregroundStyle(QiheColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(20)
            }
        }
        .navigationTitle("合同审查")
        .qiheInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .qiheTopTrailing) {
                Button {
                    appState.path.append(.chat(localRecordId: nil))
                } label: {
                    Image(systemName: "bubble.left.and.text.bubble.right")
                }
                .foregroundStyle(QiheColor.navy)
                .accessibilityLabel("打开过程页")
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: QiheDocumentValidator.allowedTypes
        ) { result in
            handleFileImport(result)
        }
    }

    private var formTitle: some View {
        VStack(spacing: 10) {
            Text("合同审查")
                .font(QiheFont.title(size: 27))
                .foregroundStyle(QiheColor.ink)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(QiheColor.navy)
                .frame(width: 44, height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var textInput: some View {
        PaperCard(padding: 14) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(QiheColor.inkSoft)
                    .frame(minHeight: 158)
                    .scrollContentBackground(.hidden)
                    .disabled(isRunning)

                if text.isEmpty {
                    Text("粘贴合同文本")
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.muted)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .background(
                LinedPaperBackground()
                    .opacity(0.72)
            )
        }
    }

    private var uploadSlot: some View {
        Button {
            isFileImporterPresented = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: attachment == nil ? "doc.badge.plus" : "doc.text")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(QiheColor.navy)

                Text(attachment?.filename ?? "上传 PDF / Word / TXT")
                    .font(QiheFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(uploadDetail)
                    .font(QiheFont.caption(size: 12))
                    .foregroundStyle(QiheColor.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 14)
            .background(QiheColor.card.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(QiheColor.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
        .disabled(isUploading || isRunning)
    }

    private var priorityNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.navy)

            Text("已上传文件，但本次将优先审查粘贴文本。")
                .font(QiheFont.body(size: 13))
                .foregroundStyle(QiheColor.navy)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.navySoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var uploadDetail: String {
        if isUploading {
            return "上传中"
        }
        if attachment != nil {
            return shouldPreferText ? "已上传，可留作参考" : "已上传，可开始审查"
        }
        return "20MB 以内"
    }

    private var hasText: Bool {
        !text.trimmedForInput.isEmpty
    }

    private var shouldPreferText: Bool {
        hasText && attachment != nil
    }

    private var requestText: String {
        let parts = [
            text.trimmedForInput,
            extraInfo.nilIfBlank.map { "补充信息：\($0)" } ?? ""
        ].filter { !$0.isEmpty }
        return parts.joined(separator: "\n\n")
    }

    private var requestFile: UploadedFile? {
        hasText ? nil : attachment
    }

    private var hasInput: Bool {
        hasText || attachment != nil
    }

    private var retryTitle: String? {
        if lastImportedURL != nil && attachment == nil {
            return "重试上传"
        }
        if hasInput {
            return "重试"
        }
        return nil
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            lastImportedURL = url
            Task {
                await upload(url)
            }
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    private func upload(_ url: URL) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do {
            attachment = try await appState.apiClient.uploadFile(from: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func runReview() async {
        guard hasInput else {
            return
        }
        isRunning = true
        errorMessage = nil
        defer { isRunning = false }

        do {
            var result = try await appState.apiClient.runReview(text: requestText, file: requestFile)
            let source = ContractSource(
                textPreview: result.source?.textPreview ?? requestText.truncated(to: 240),
                fileId: result.source?.fileId ?? requestFile?.fileId,
                filename: result.source?.filename ?? requestFile?.filename,
                originalText: result.source?.originalText ?? requestText.nilIfBlank
            )
            result.source = source
            let id = historyStore.saveReview(
                requestText: requestText,
                attachment: attachment,
                result: result
            )
            appState.path.append(.reviewResult(recordId: id))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func retry() {
        if let lastImportedURL, attachment == nil {
            Task {
                await upload(lastImportedURL)
            }
        } else if hasInput {
            Task {
                await runReview()
            }
        }
    }
}

private struct LinedPaperBackground: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let lineHeight: CGFloat = 28
                var y = lineHeight
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += lineHeight
                }
            }
            .stroke(QiheColor.line, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
