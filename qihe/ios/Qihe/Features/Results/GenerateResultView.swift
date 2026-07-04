import SwiftUI

struct GenerateResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let result = historyStore.record(id: recordId)?.generateResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            SealMark(size: 30)
                            Text(result.title)
                                .font(QiheFont.title(size: 22))
                            Spacer()
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("合同草案")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(result.draft)
                                    .font(.system(size: 14))
                                    .foregroundStyle(QiheColor.ink)
                                    .textSelection(.enabled)
                            }
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("待补充字段")
                                    .font(.system(size: 16, weight: .semibold))
                                if result.missingFields.isEmpty {
                                    Text("暂无")
                                        .foregroundStyle(QiheColor.muted)
                                } else {
                                    ForEach(result.missingFields, id: \.self) { field in
                                        Label(field, systemImage: "exclamationmark.circle")
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("签署前清单")
                                    .font(.system(size: 16, weight: .semibold))
                                ForEach(result.preSignChecklist, id: \.self) { item in
                                    Label(item, systemImage: "checkmark.circle")
                                        .font(.system(size: 14))
                                }
                            }
                        }

                        if !result.notes.isEmpty {
                            PaperCard {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("说明")
                                        .font(.system(size: 16, weight: .semibold))
                                    ForEach(result.notes, id: \.self) { note in
                                        Text(note)
                                            .font(.system(size: 13))
                                            .foregroundStyle(QiheColor.muted)
                                    }
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(QiheColor.seal)
                        }

                        HStack {
                            Button {
                                Task {
                                    await export(result)
                                }
                            } label: {
                                Label(isExporting ? "导出中" : "导出 Word", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isExporting)

                            if let exportURL {
                                ShareLink(item: exportURL) {
                                    Label("分享", systemImage: "doc")
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                Text("未找到本地生成记录")
                    .foregroundStyle(QiheColor.muted)
            }
        }
    }

    private func export(_ result: GenerateResult) async {
        errorMessage = nil
        isExporting = true
        do {
            let data = try await appState.apiClient.exportGenerateWord(title: result.title, result: result)
            exportURL = try writeGenerateExport(data: data, title: result.title)
        } catch {
            errorMessage = error.localizedDescription
        }
        isExporting = false
    }
}

private func writeGenerateExport(data: Data, title: String) throws -> URL {
    let safeTitle = title.replacingOccurrences(of: "/", with: "-")
    let url = FileManager.default.temporaryDirectory.appending(path: "\(safeTitle).docx")
    try data.write(to: url, options: .atomic)
    return url
}
