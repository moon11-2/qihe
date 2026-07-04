import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore

    private let localRecordId: UUID?
    private let apiClient: APIClient

    @State private var recordId: UUID?
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var errorMessage: String?
    @State private var lastFailedUserMessageId: UUID?
    @State private var suggestedModes: Set<ContractMode> = []
    @State private var isSending = false
    @State private var didRestoreHistory = false

    init(localRecordId: UUID?, apiClient: APIClient = .local) {
        self.localRecordId = localRecordId
        self.apiClient = apiClient
        _recordId = State(initialValue: localRecordId)
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        processCard

                        if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                ChatBubble(message: message)
                            }
                        }

                        if isSending {
                            TypingIndicator()
                        }

                        Color.clear
                            .frame(height: 1)
                            .id(Self.bottomAnchorId)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .onChange(of: messages) {
                    scrollToBottom(proxy)
                }
                .onChange(of: isSending) {
                    scrollToBottom(proxy)
                }
                .onAppear {
                    restoreHistoryIfNeeded()
                    scrollToBottom(proxy, animated: false)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .navigationTitle("过程对话")
        .qiheInlineNavigationTitle()
    }

    private var processCard: some View {
        PaperCard(padding: 14) {
            VStack(spacing: 12) {
                ProcessNode(
                    title: "上下文",
                    detail: messages.isEmpty ? "尚未开始" : "\(messages.count) 条消息已保存在本地上下文",
                    isActive: isSending,
                    isDone: !messages.isEmpty
                )

                ProcessNode(
                    title: "下一步",
                    detail: nextStepDetail,
                    isActive: latestUserInput != nil && !isSending,
                    isDone: !suggestedModes.isEmpty
                )
            }
        }
    }

    private var emptyState: some View {
        PaperCard {
            EmptyStateView(
                title: "开始过程对话",
                detail: "输入合同背景、审查问题或生成需求；对话会作为后续审查和生成的预填内容。"
            )
        }
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                ErrorBanner(message: errorMessage, retryTitle: "重试") {
                    retryLastUserMessage()
                }
            }

            handoffPanel

            HStack(alignment: .bottom, spacing: 10) {
                TextField("输入合同问题或处理目标", text: $input, axis: .vertical)
                    .font(QiheFont.body(size: 15))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(QiheColor.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(QiheColor.line, lineWidth: 1)
                    )
                    .disabled(isSending)

                Button {
                    sendCurrentInput()
                } label: {
                    ZStack {
                        if isSending {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.white)
                    .background(canSend ? QiheColor.navy : QiheColor.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel(isSending ? "正在发送" : "发送")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(QiheColor.paper)
    }

    @ViewBuilder
    private var handoffPanel: some View {
        if latestUserInput != nil {
            PaperCard(padding: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("进入处理")
                            .font(QiheFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)

                        Spacer()

                        if !suggestedModes.isEmpty {
                            QiheStatusPill(text: "已推荐")
                        }
                    }

                    HStack(spacing: 10) {
                        ForEach(availableActionModes, id: \.self) { mode in
                            QiheSecondaryButton(
                                title: mode.actionTitle,
                                systemImage: mode.systemImage,
                                isDisabled: isSending
                            ) {
                                openMode(mode)
                            }
                        }
                    }
                }
            }
        }
    }

    private var canSend: Bool {
        !isSending && input.trimmedForInput.nilIfBlank != nil
    }

    private var latestUserInput: String? {
        messages.reversed()
            .first { $0.role == .user }?
            .content
            .nilIfBlank
    }

    private var availableActionModes: [ContractMode] {
        let orderedModes: [ContractMode] = [.review, .generate]
        guard !suggestedModes.isEmpty else {
            return orderedModes
        }
        return orderedModes.filter { suggestedModes.contains($0) }
    }

    private var nextStepDetail: String {
        if isSending {
            return "正在等待后端回复"
        }

        if !suggestedModes.isEmpty {
            return "可转入\(availableActionModes.map(\.label).joined(separator: "或"))"
        }

        if latestUserInput != nil {
            return "可转入合同审查或合同生成"
        }

        return "等待最近一次用户输入"
    }

    @MainActor
    private func restoreHistoryIfNeeded() {
        guard !didRestoreHistory else {
            return
        }
        didRestoreHistory = true

        guard let localRecordId else {
            return
        }

        guard let record = historyStore.record(id: localRecordId),
              record.type == .chat,
              let restoredMessages = record.chatPayload?.messages else {
            recordId = nil
            return
        }

        recordId = record.id
        messages = restoredMessages
        suggestedModes = []
        errorMessage = nil
        lastFailedUserMessageId = nil
    }

    @MainActor
    private func sendCurrentInput() {
        let text = input.trimmedForInput
        guard !isSending, !text.isEmpty else {
            return
        }

        let userMessage = ChatMessage(role: .user, content: text)
        input = ""
        errorMessage = nil
        lastFailedUserMessageId = nil
        suggestedModes = []
        messages.append(userMessage)
        isSending = true
        let requestMessages = messages

        Task {
            await submitMessages(requestMessages, failedUserMessageId: userMessage.id)
        }
    }

    @MainActor
    private func retryLastUserMessage() {
        guard !isSending else {
            return
        }

        let failedMessageId = lastFailedUserMessageId ?? messages.reversed().first { $0.role == .user }?.id
        guard let failedMessageId else {
            return
        }

        errorMessage = nil
        suggestedModes = []
        isSending = true
        let requestMessages = messages

        Task {
            await submitMessages(requestMessages, failedUserMessageId: failedMessageId)
        }
    }

    @MainActor
    private func submitMessages(_ requestMessages: [ChatMessage], failedUserMessageId: UUID) async {
        do {
            let response = try await apiClient.chat(messages: requestMessages)
            let reply = response.reply.nilIfBlank ?? "已收到你的请求，但服务未返回文本回复。"
            messages.append(ChatMessage(role: .assistant, content: reply))
            suggestedModes = modes(from: response)
            lastFailedUserMessageId = nil
            errorMessage = nil
        } catch {
            lastFailedUserMessageId = failedUserMessageId
            errorMessage = error.localizedDescription.nilIfBlank ?? "发送失败，请稍后重试。"
        }

        persistMessages()
        isSending = false
    }

    @MainActor
    private func persistMessages() {
        guard !messages.isEmpty else {
            return
        }
        recordId = historyStore.saveChat(recordId: recordId, messages: messages)
    }

    @MainActor
    private func openMode(_ mode: ContractMode) {
        guard let prefill = latestUserInput else {
            return
        }

        persistMessages()
        switch mode {
        case .review:
            appState.path.append(.review(prefill: prefill))
        case .generate:
            appState.path.append(.generate(prefill: prefill))
        }
    }

    private func modes(from response: ChatResponse) -> Set<ContractMode> {
        var modes = Set(response.options)
        if let intentMode = ContractMode(rawValue: response.intent) {
            modes.insert(intentMode)
        }
        return modes
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let action = {
            proxy.scrollTo(Self.bottomAnchorId, anchor: .bottom)
        }

        if animated {
            withAnimation(.easeOut(duration: 0.2), action)
        } else {
            action()
        }
    }

    private static let bottomAnchorId = "chat-bottom-anchor"
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 54)
            }

            VStack(alignment: alignment, spacing: 6) {
                Text(roleTitle)
                    .font(QiheFont.caption(size: 11, weight: .semibold))
                    .foregroundStyle(titleColor)

                Text(message.content)
                    .font(QiheFont.body(size: 15))
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(borderColor, lineWidth: message.role == .user ? 0 : 1)
                    )
            }

            if message.role != .user {
                Spacer(minLength: 54)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    private var roleTitle: String {
        switch message.role {
        case .system:
            return "系统"
        case .user:
            return "你"
        case .assistant:
            return "契合"
        }
    }

    private var alignment: HorizontalAlignment {
        message.role == .user ? .trailing : .leading
    }

    private var titleColor: Color {
        message.role == .user ? QiheColor.navy : QiheColor.muted
    }

    private var textColor: Color {
        message.role == .user ? .white : QiheColor.inkSoft
    }

    private var background: Color {
        switch message.role {
        case .system:
            return QiheColor.paperDeep
        case .user:
            return QiheColor.navy
        case .assistant:
            return QiheColor.card
        }
    }

    private var borderColor: Color {
        message.role == .system ? QiheColor.lineStrong : QiheColor.line
    }
}

private struct TypingIndicator: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(QiheColor.navy)

                Text("正在整理回复")
                    .font(QiheFont.body(size: 14, weight: .medium))
                    .foregroundStyle(QiheColor.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(QiheColor.line, lineWidth: 1)
            )

            Spacer(minLength: 54)
        }
    }
}

private extension ContractMode {
    var label: String {
        switch self {
        case .review:
            return "合同审查"
        case .generate:
            return "合同生成"
        }
    }

    var actionTitle: String {
        switch self {
        case .review:
            return "审查"
        case .generate:
            return "生成"
        }
    }

    var systemImage: String {
        switch self {
        case .review:
            return "doc.text.magnifyingglass"
        case .generate:
            return "doc.text.fill"
        }
    }
}
