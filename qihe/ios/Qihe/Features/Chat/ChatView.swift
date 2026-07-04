import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    let localRecordId: UUID?
    @State private var input = ""
    @State private var messages: [ChatMessage] = [
        ChatMessage(role: "assistant", content: "你可以问合同相关问题，也可以说明要审查合同或生成合同。")
    ]
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        VStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundStyle(QiheColor.seal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }

            HStack {
                TextField("请输入问题", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSending)

                Button {
                    Task {
                        await send()
                    }
                } label: {
                    Image(systemName: isSending ? "hourglass.circle.fill" : "arrow.up.circle.fill")
                        .foregroundStyle(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? QiheColor.muted : QiheColor.navy)
                }
                .disabled(isSending || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("契合")
        .qiheInlineNavigationTitle()
        .onAppear {
            if let localRecordId,
               let record = historyStore.record(id: localRecordId),
               !record.chatMessages.isEmpty {
                messages = record.chatMessages
            }
        }
    }

    private func send() async {
        let content = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else {
            return
        }

        errorMessage = nil
        isSending = true
        input = ""
        messages.append(ChatMessage(role: "user", content: content))

        do {
            let response = try await appState.apiClient.chat(messages: messages)
            messages.append(ChatMessage(role: "assistant", content: response.reply))
            historyStore.addChat(messages: messages, title: content)

            if response.route == "review" {
                appState.path.append(.review(prefill: content))
            } else if response.route == "generate" {
                appState.path.append(.generate(prefill: content))
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSending = false
    }
}

private extension View {
    @ViewBuilder
    func qiheInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        Text(message.content)
            .font(.system(size: 15))
            .foregroundStyle(message.role == "user" ? .white : QiheColor.ink)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
            .background(message.role == "user" ? QiheColor.navy : QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
