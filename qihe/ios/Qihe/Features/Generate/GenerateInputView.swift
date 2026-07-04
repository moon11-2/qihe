import SwiftUI

struct GenerateInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var isRunning = false
    @State private var errorMessage: String?

    init(prefill: String?) {
        _text = State(initialValue: prefill ?? "")
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("合同生成")
                    .font(QiheFont.title(size: 28))

                PaperCard {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13))
                        .foregroundStyle(QiheColor.seal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                QihePrimaryButton(title: isRunning ? "生成中" : "生成合同") {
                    Task {
                        await runGenerate()
                    }
                }
                .disabled(isRunning)
            }
            .padding(20)
        }
    }

    private func runGenerate() async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            errorMessage = "请先输入合同生成需求。"
            return
        }

        errorMessage = nil
        isRunning = true
        do {
            let response = try await appState.apiClient.runContract(
                ContractRunRequest(
                    mode: "generate",
                    text: trimmedText,
                    fileId: nil,
                    metadata: [:]
                )
            )
            guard let result = response.generateResult else {
                throw APIClientError.invalidResponse
            }
            let record = historyStore.addGenerate(result)
            appState.path.append(.generateResult(recordId: record.id))
        } catch {
            errorMessage = error.localizedDescription
        }
        isRunning = false
    }
}
