import SwiftUI
import UniformTypeIdentifiers

struct ReviewInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var uploadedFile: FileUploadResponse?
    @State private var isImporterPresented = false
    @State private var isUploading = false
    @State private var isRunning = false
    @State private var errorMessage: String?

    private let allowedFileTypes: [UTType] = [
        .pdf,
        .plainText,
        UTType(filenameExtension: "docx") ?? .data,
    ]

    init(prefill: String?) {
        _text = State(initialValue: prefill ?? "")
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("合同审查")
                    .font(QiheFont.title(size: 28))

                PaperCard {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                }

                Button {
                    isImporterPresented = true
                } label: {
                    Label(isUploading ? "上传中" : "上传 PDF / Word / TXT", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(isUploading || isRunning)

                if let uploadedFile {
                    PaperCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(uploadedFile.filename)
                                .font(.system(size: 15, weight: .semibold))
                            Text(uploadedFile.textPreview.isEmpty ? "文件已上传，未抽取到预览文本。" : uploadedFile.textPreview)
                                .font(.system(size: 13))
                                .foregroundStyle(QiheColor.inkSoft)
                                .lineLimit(3)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(QiheColor.seal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                QihePrimaryButton(title: isRunning ? "审查中" : "开始审查") {
                    Task {
                        await runReview()
                    }
                }
                .disabled(isRunning || isUploading)
            }
            .padding(20)
        }
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            Task {
                await handleImport(result)
            }
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) async {
        errorMessage = nil
        do {
            guard let url = try result.get().first else {
                return
            }
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            isUploading = true
            uploadedFile = try await appState.apiClient.uploadFile(fileURL: url)
            isUploading = false
        } catch {
            isUploading = false
            errorMessage = error.localizedDescription
        }
    }

    private func runReview() async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty || uploadedFile != nil else {
            errorMessage = "请粘贴合同正文或上传 PDF、DOCX、TXT 文件。"
            return
        }

        errorMessage = nil
        isRunning = true
        do {
            let response = try await appState.apiClient.runContract(
                ContractRunRequest(
                    mode: "review",
                    text: trimmedText.isEmpty ? nil : trimmedText,
                    fileId: uploadedFile?.fileId,
                    metadata: [:]
                )
            )
            guard let result = response.reviewResult else {
                throw APIClientError.invalidResponse
            }
            let record = historyStore.addReview(result)
            appState.path.append(.reviewResult(recordId: record.id))
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}
