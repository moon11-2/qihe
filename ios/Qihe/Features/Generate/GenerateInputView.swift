import SwiftUI

struct GenerateInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var isSupplementExpanded = false
    @State private var contractType = ""
    @State private var myIdentity = ""
    @State private var specialTerms = ""
    @State private var attachment: UploadedFile?
    @State private var isFileImporterPresented = false
    @State private var isUploading = false
    @State private var isRunning = false
    @State private var activeGenerateRunID: UUID?
    @State private var generationTask: Task<Void, Never>?
    @State private var errorMessage: String?
    @State private var lastImportedURL: URL?

    init(prefill: String?) {
        _text = State(initialValue: prefill ?? "")
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()
                .onTapGesture {
                    QiheKeyboard.dismiss()
                }

            ScrollView {
                VStack(spacing: 16) {
                    QiheSectionHeader(
                        title: "合同生成",
                        subtitle: "提交后会生成草案、待补充字段和签署前清单。"
                    )

                    if let errorMessage {
                        ErrorBanner(message: errorMessage, retryTitle: retryTitle) {
                            retry()
                        }
                    }

                    PaperCard {
                        TextEditor(text: $text)
                            .font(QiheFont.body(size: 15))
                            .frame(minHeight: 220)
                            .scrollContentBackground(.hidden)
                            .disabled(isRunning)
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("描述合同类型、双方身份、金额、期限和关键约定。")
                                        .font(QiheFont.body(size: 15))
                                        .foregroundStyle(QiheColor.muted)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    supplementSection

                    attachmentSection

                    PaperCard {
                        VStack(spacing: 12) {
                            ProcessNode(
                                title: "整理需求",
                                detail: hasInput ? "已准备生成材料。" : "先输入需求或上传参考文件。",
                                isDone: hasInput
                            )
                            ProcessNode(
                                title: "生成草案",
                                detail: "输出可复制、可导出的合同正文。",
                                isActive: isRunning
                            )
                            ProcessNode(
                                title: "签前核对",
                                detail: "补充字段和清单会放在结果页。",
                                isDone: false
                            )
                        }
                    }

                    actionArea
                }
                .padding(20)
            }
            .qiheScrollDismissesKeyboard()
        }
        .navigationTitle("合同生成")
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

    private var supplementSection: some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isSupplementExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: isSupplementExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(QiheColor.navy)
                            .frame(width: 18)

                        Text("补充要求")
                            .font(QiheFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)

                        QiheStatusPill(
                            text: hasSupplementRequirements ? "已填写" : "可选",
                            color: hasSupplementRequirements ? QiheColor.navy : QiheColor.muted,
                            background: hasSupplementRequirements ? QiheColor.navySoft : QiheColor.paperDeep
                        )

                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isSupplementExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        GenerateMetadataTextField(
                            title: "合同类型",
                            placeholder: "如：房屋租赁合同",
                            text: $contractType,
                            isDisabled: isRunning
                        )

                        GenerateMetadataTextField(
                            title: "我的身份",
                            placeholder: "如：甲方 / 出租方 / 买方",
                            text: $myIdentity,
                            isDisabled: isRunning
                        )

                        GenerateMetadataTextField(
                            title: "特殊约定",
                            placeholder: "金额、期限、交付标准、违约责任等",
                            text: $specialTerms,
                            lineLimit: 2...5,
                            isDisabled: isRunning
                        )
                    }
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 10) {
            QihePrimaryButton(
                title: "生成合同",
                systemImage: "doc.text.fill",
                isLoading: isRunning,
                isDisabled: !hasInput || isUploading
            ) {
                startGenerate()
            }

            if isRunning {
                QiheSecondaryButton(title: "取消", systemImage: "xmark.circle") {
                    cancelGenerate()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var attachmentSection: some View {
        VStack(spacing: 10) {
            AttachmentRow(
                title: attachment?.filename ?? "上传参考文件",
                detail: attachment == nil ? "仅 PDF、Word/DOCX、TXT" : "已上传，可用于生成",
                actionTitle: isUploading ? "上传中" : (attachment == nil ? "选择" : "更换"),
                systemImage: attachment == nil ? "doc.badge.plus" : "doc.text",
                isDisabled: isUploading || isRunning
            ) {
                isFileImporterPresented = true
            }

            if attachment != nil {
                QiheSecondaryButton(
                    title: "移除附件",
                    systemImage: "trash",
                    isDisabled: isUploading || isRunning
                ) {
                    removeAttachment()
                }
            }
        }
    }

    private var hasInput: Bool {
        !text.trimmedForInput.isEmpty || attachment != nil || hasSupplementRequirements
    }

    private var hasSupplementRequirements: Bool {
        contractType.nilIfBlank != nil
            || myIdentity.nilIfBlank != nil
            || specialTerms.nilIfBlank != nil
    }

    private var requestMetadata: [String: JSONValue] {
        var metadata: [String: JSONValue] = [:]

        if let contractType = contractType.nilIfBlank {
            metadata["contract_type"] = .string(contractType)
        }
        if let myIdentity = myIdentity.nilIfBlank {
            metadata["my_identity"] = .string(myIdentity)
            metadata["role"] = .string(myIdentity)
        }
        if let specialTerms = specialTerms.nilIfBlank {
            metadata["special_terms"] = .string(specialTerms)
            metadata["key_terms"] = .string(specialTerms)
        }

        return metadata
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
            errorMessage = error.qiheDisplayMessage
        }
    }

    private func upload(_ url: URL) async {
        isUploading = true
        errorMessage = nil
        defer { isUploading = false }

        do {
            attachment = try await appState.apiClient.uploadFile(from: url)
        } catch {
            errorMessage = error.qiheDisplayMessage
        }
    }

    private func removeAttachment() {
        attachment = nil
        lastImportedURL = nil
        errorMessage = nil
    }

    @MainActor
    private func startGenerate() {
        guard hasInput, generationTask == nil else {
            return
        }
        QiheKeyboard.dismiss()

        let runID = UUID()
        let requestText = text
        let requestAttachment = attachment
        let metadata = requestMetadata

        isRunning = true
        errorMessage = nil
        activeGenerateRunID = runID

        generationTask = Task {
            await runGenerate(
                runID: runID,
                requestText: requestText,
                requestAttachment: requestAttachment,
                metadata: metadata
            )
        }
    }

    @MainActor
    private func cancelGenerate() {
        generationTask?.cancel()
        generationTask = nil
        activeGenerateRunID = nil
        isRunning = false
    }

    @MainActor
    private func runGenerate(
        runID: UUID,
        requestText: String,
        requestAttachment: UploadedFile?,
        metadata: [String: JSONValue]
    ) async {
        defer {
            finishGenerate(runID: runID)
        }

        do {
            var result = try await appState.apiClient.runGenerate(
                text: requestText,
                file: requestAttachment,
                metadata: metadata
            )
            guard !Task.isCancelled, activeGenerateRunID == runID else {
                return
            }
            let source = ContractSource(
                textPreview: result.source?.textPreview ?? requestText.truncated(to: 240),
                fileId: result.source?.fileId ?? requestAttachment?.fileId,
                filename: result.source?.filename ?? requestAttachment?.filename,
                originalText: result.source?.originalText ?? requestText.nilIfBlank
            )
            result.source = source
            let id = historyStore.saveGenerate(
                requestText: requestText,
                attachment: requestAttachment,
                result: result
            )
            appState.path.append(.generateResult(recordId: id))
        } catch {
            guard !isCancellation(error), activeGenerateRunID == runID else {
                return
            }
            errorMessage = error.qiheDisplayMessage
        }
    }

    @MainActor
    private func finishGenerate(runID: UUID) {
        guard activeGenerateRunID == runID else {
            return
        }
        generationTask = nil
        activeGenerateRunID = nil
        isRunning = false
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func retry() {
        if let lastImportedURL, attachment == nil {
            Task {
                await upload(lastImportedURL)
            }
        } else if hasInput {
            startGenerate()
        }
    }
}

private struct GenerateMetadataTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var lineLimit: ClosedRange<Int> = 1...1
    var isDisabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.muted)

            TextField(placeholder, text: $text, axis: .vertical)
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .lineLimit(lineLimit)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(QiheColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(QiheColor.line, lineWidth: 1)
                )
                .disabled(isDisabled)
        }
    }
}
