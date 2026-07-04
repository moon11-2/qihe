import SwiftUI

struct ReviewInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var attachment: UploadedFile?
    @State private var isFileImporterPresented = false
    @State private var isUploading = false
    @State private var isRunning = false
    @State private var errorMessage: String?
    @State private var lastImportedURL: URL?

    init(prefill: String?) {
        _text = State(initialValue: prefill ?? "")
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    QiheSectionHeader(
                        title: "合同审查",
                        subtitle: "提交后会展示原文、风险和主体信息。"
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
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("粘贴合同正文，或上传支持格式的合同文件。")
                                        .font(QiheFont.body(size: 15))
                                        .foregroundStyle(QiheColor.muted)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            }
                    }

                    AttachmentRow(
                        title: attachment?.filename ?? "上传合同文件",
                        detail: attachment == nil ? "仅 PDF、Word/DOCX、TXT" : "已上传，可开始审查",
                        actionTitle: isUploading ? "上传中" : "选择",
                        systemImage: attachment == nil ? "doc.badge.plus" : "doc.text",
                        isDisabled: isUploading || isRunning
                    ) {
                        isFileImporterPresented = true
                    }

                    PaperCard {
                        VStack(spacing: 12) {
                            ProcessNode(
                                title: "读取材料",
                                detail: hasInput ? "已准备审查材料。" : "先粘贴文本或上传文件。",
                                isDone: hasInput
                            )
                            ProcessNode(
                                title: "识别风险",
                                detail: "按条款展示风险等级、原文和建议。",
                                isActive: isRunning
                            )
                            ProcessNode(
                                title: "整理主体",
                                detail: "主体信息将在结果页单独展示。",
                                isDone: false
                            )
                        }
                    }

                    QihePrimaryButton(
                        title: "开始审查",
                        systemImage: "doc.text.magnifyingglass",
                        isLoading: isRunning,
                        isDisabled: !hasInput
                    ) {
                        Task {
                            await runReview()
                        }
                    }
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

    private var hasInput: Bool {
        !text.trimmedForInput.isEmpty || attachment != nil
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
            var result = try await appState.apiClient.runReview(text: text, file: attachment)
            let source = ContractSource(
                textPreview: result.source?.textPreview ?? text.truncated(to: 240),
                fileId: result.source?.fileId ?? attachment?.fileId,
                filename: result.source?.filename ?? attachment?.filename,
                originalText: result.source?.originalText ?? text.nilIfBlank
            )
            result.source = source
            let id = historyStore.saveReview(
                requestText: text,
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
