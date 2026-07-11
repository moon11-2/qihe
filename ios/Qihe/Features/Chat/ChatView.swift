import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var historyStore: HistoryStore

    private let localRecordId: UUID?
    private let initialMessage: String?
    private let apiClient: APIClient

    @State private var recordId: UUID?
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var errorMessage: String?
    @State private var lastFailedUserMessageId: UUID?
    @State private var suggestedModes: Set<ContractMode> = []
    @State private var actionRecommendations: [UUID: ChatActionRecommendation] = [:]
    @State private var isSending = false
    @State private var didRestoreHistory = false
    @State private var didSubmitInitialMessage = false
    @FocusState private var isInputFocused: Bool

    init(localRecordId: UUID?, initialMessage: String? = nil, apiClient: APIClient = .local) {
        self.localRecordId = localRecordId
        self.initialMessage = initialMessage
        self.apiClient = apiClient
        _recordId = State(initialValue: localRecordId)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xE6F0FF), Color(hex: 0xF5FAFF)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
                .onTapGesture {
                    isInputFocused = false
                    QiheKeyboard.dismiss()
                }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { message in
                                ChatBubble(
                                    message: message,
                                    recommendation: actionRecommendations[message.id],
                                    isActionDisabled: isSending
                                ) { mode in
                                    openMode(mode, prefill: actionRecommendations[message.id]?.prefill)
                                }
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
                .qiheScrollDismissesKeyboard()
                .onTapGesture {
                    isInputFocused = false
                    QiheKeyboard.dismiss()
                }
                .onChange(of: messages) {
                    scrollToBottom(proxy)
                }
                .onChange(of: isSending) {
                    scrollToBottom(proxy)
                }
                .onAppear {
                    restoreHistoryIfNeeded()
                    submitInitialMessageIfNeeded()
                    scrollToBottom(proxy, animated: false)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            composer
        }
        .navigationTitle("小契 · 智能助手")
        .qiheInlineNavigationTitle()
#if os(iOS)
        .toolbarBackground(Color.white.opacity(0.74), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
#endif
    }

    private var processCard: some View {
        PaperCard(padding: 14) {
            VStack(spacing: 12) {
                ProcessNode(
                    title: "解析文本",
                    detail: messages.isEmpty ? "等待你的第一句话" : "\(messages.count) 条消息已保存在本地上下文",
                    isActive: isSending,
                    isDone: !messages.isEmpty
                )

                ProcessNode(
                    title: "识别意图",
                    detail: nextStepDetail,
                    isActive: latestUserInput != nil && !isSending,
                    isDone: !suggestedModes.isEmpty
                )
            }
        }
    }

    private var emptyState: some View {
        ChatWelcomeBubble()
    }

    private var composer: some View {
        VStack(spacing: 10) {
            if !authStore.status.isSignedIn {
                ErrorBanner(message: "请登录后使用", retryTitle: "去登录") {
                    openSignIn()
                }
            } else if let errorMessage {
                ErrorBanner(message: errorMessage, retryTitle: "重试") {
                    retryLastUserMessage()
                }
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("输入合同问题或处理目标", text: $input, axis: .vertical)
                    .font(QiheFont.body(size: 15))
                    .foregroundStyle(Color(hex: 0x14203A))
                    .tint(Color(hex: 0x2563EB))
                    .lineLimit(1...4)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(hex: 0x2563EB).opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color(hex: 0x2563EB).opacity(0.08), radius: 8, x: 0, y: 3)
                    .focused($isInputFocused)
                    .disabled(isSending)

                ChatSendButton(
                    isLoading: isSending,
                    isDisabled: !canSend
                ) {
                    sendCurrentInput()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 9)
        .padding(.bottom, 10)
        .background(Color.white.opacity(0.88))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(hex: 0x2563EB).opacity(0.08))
                .frame(height: 1)
        }
    }

    private var canSend: Bool {
        authStore.status.isSignedIn && !isSending && input.trimmedForInput.nilIfBlank != nil
    }

    private var latestUserInput: String? {
        messages.reversed()
            .first { $0.role == .user }?
            .content
            .nilIfBlank
    }

    private var nextStepDetail: String {
        if isSending {
            return "正在生成回复"
        }

        if !suggestedModes.isEmpty {
            return "最新回复已提供\(orderedModes(from: suggestedModes).map(\.label).joined(separator: "或"))入口"
        }

        if latestUserInput != nil {
            return "继续对话，AI 会在回复中给出入口"
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
        actionRecommendations = [:]
        errorMessage = nil
        lastFailedUserMessageId = nil
    }

    @MainActor
    private func sendCurrentInput() {
        guard requireSignIn() else {
            return
        }
        let text = input.trimmedForInput
        guard !isSending, !text.isEmpty else {
            return
        }
        isInputFocused = false
        QiheKeyboard.dismiss()
        input = ""
        submitUserText(text)
    }

    @MainActor
    private func submitInitialMessageIfNeeded() {
        guard !didSubmitInitialMessage else {
            return
        }
        didSubmitInitialMessage = true

        guard localRecordId == nil,
              messages.isEmpty,
              let text = initialMessage?.trimmedForInput.nilIfBlank else {
            return
        }

        guard requireSignIn() else {
            return
        }
        submitUserText(text)
    }

    @MainActor
    private func submitUserText(_ text: String) {
        guard requireSignIn() else {
            return
        }
        guard !isSending, !text.isEmpty else {
            return
        }
        let userMessage = ChatMessage(role: .user, content: text)
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
        guard requireSignIn() else {
            return
        }
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
            let assistantMessage = ChatMessage(role: .assistant, content: reply)
            messages.append(assistantMessage)
            suggestedModes = modes(from: response)
            if let recommendation = recommendation(from: response, prefill: latestUserInput(in: requestMessages)) {
                actionRecommendations[assistantMessage.id] = recommendation
            }
            lastFailedUserMessageId = nil
            errorMessage = nil
        } catch {
            lastFailedUserMessageId = failedUserMessageId
            errorMessage = error.qiheDisplayMessage.nilIfBlank ?? "发送失败，请稍后重试。"
        }

        persistMessages()
        isSending = false
    }

    @MainActor
    @discardableResult
    private func persistMessages() -> UUID? {
        guard !messages.isEmpty else {
            return nil
        }
        recordId = historyStore.saveChat(recordId: recordId, messages: messages)
        return recordId
    }

    @MainActor
    private func openMode(_ mode: ContractMode, prefill recommendedPrefill: String? = nil) {
        guard requireSignIn() else {
            return
        }
        guard let prefill = recommendedPrefill?.nilIfBlank ?? latestUserInput else {
            return
        }

        let persistedChatRecordId = persistMessages()
        switch mode {
        case .review:
            appState.path.append(.review(prefill: prefill))
        case .generate:
            appState.path.append(
                .generate(
                    prefill: prefill,
                    sourceChatRecordId: persistedChatRecordId
                )
            )
        }
    }

    private func modes(from response: ChatResponse) -> Set<ContractMode> {
        var modes = Set(response.options)
        response.needInput.flatMap(contractModes(from:)).forEach { modes.insert($0) }
        if let route = response.route {
            modes.insert(route)
        }
        contractModes(from: response.intent).forEach { modes.insert($0) }
        return modes
    }

    private func recommendation(from response: ChatResponse, prefill: String?) -> ChatActionRecommendation? {
        guard let prefill = prefill?.nilIfBlank else {
            return nil
        }

        if let route = response.route {
            return ChatActionRecommendation(
                action: .enter(route),
                prefill: prefill
            )
        }

        let intentModes = contractModes(from: response.intent)
        if intentModes.count == 1, let intentMode = intentModes.first {
            return ChatActionRecommendation(
                action: .enter(intentMode),
                prefill: prefill
            )
        }

        let responseModes = orderedModes(from: modes(from: response))
        if isAmbiguousNeedInput(response, modes: responseModes) {
            return ChatActionRecommendation(
                action: .choose(Self.modeOrder),
                prefill: prefill
            )
        }

        guard responseModes.count == 1, let responseMode = responseModes.first else {
            return nil
        }
        return ChatActionRecommendation(
            action: .enter(responseMode),
            prefill: prefill
        )
    }

    private func isAmbiguousNeedInput(_ response: ChatResponse, modes: [ContractMode]) -> Bool {
        response.type.trimmedForInput.lowercased() == "need_input"
            && response.route == nil
            && contractModes(from: response.intent).isEmpty
            && Set(modes) == Set(Self.modeOrder)
    }

    private func latestUserInput(in messages: [ChatMessage]) -> String? {
        messages.reversed()
            .first { $0.role == .user }?
            .content
            .nilIfBlank
    }

    private func contractModes(from rawValue: String) -> [ContractMode] {
        let normalized = rawValue.trimmedForInput.lowercased()
        guard !normalized.isEmpty else {
            return []
        }

        var modes = Set<ContractMode>()
        if normalized.contains("审查") {
            modes.insert(.review)
        }
        if normalized.contains("生成") {
            modes.insert(.generate)
        }

        normalized
            .split { !$0.isLetter }
            .compactMap { ContractMode(rawValue: String($0)) }
            .forEach { modes.insert($0) }

        if let mode = ContractMode(rawValue: normalized) {
            modes.insert(mode)
        }

        return orderedModes(from: modes)
    }

    private func orderedModes(from modes: Set<ContractMode>) -> [ContractMode] {
        Self.modeOrder.filter { modes.contains($0) }
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
    private static let modeOrder: [ContractMode] = [.review, .generate]

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
}

private struct ChatSendButton: View {
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(width: 40, height: 40)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [Color(hex: 0x3B82F6), Color(hex: 0x2563EB)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .shadow(color: Color(hex: 0x2563EB).opacity(isDisabled ? 0 : 0.28), radius: 7, x: 0, y: 4)
            .opacity(isDisabled ? 0.52 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(isLoading ? "正在发送" : "发送")
    }
}

private struct ChatBubble: View {
    let message: ChatMessage
    var recommendation: ChatActionRecommendation?
    var isActionDisabled = false
    let onSelectMode: (ContractMode) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 48)
            } else {
                leadingAvatar
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(message.content)
                    .font(QiheFont.body(size: 14))
                    .lineSpacing(3)
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)

                if message.role == .assistant, let recommendation {
                    ChatRecommendationActions(
                        recommendation: recommendation,
                        isDisabled: isActionDisabled,
                        onSelectMode: onSelectMode
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(bubbleBackground)
            .clipShape(bubbleShape)
            .shadow(
                color: message.role == .user
                    ? Color(hex: 0x2563EB).opacity(0.24)
                    : Color(hex: 0x2563EB).opacity(0.08),
                radius: message.role == .user ? 10 : 8,
                x: 0,
                y: message.role == .user ? 5 : 3
            )

            if message.role != .user {
                Spacer(minLength: 48)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    @ViewBuilder
    private var leadingAvatar: some View {
        switch message.role {
        case .assistant:
            QiheAssistantAvatar(size: 32)
        case .system:
            Image(systemName: "info.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(QiheColor.brandBlue)
                .frame(width: 32, height: 32)
                .background(QiheColor.infoBlueSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        case .user:
            EmptyView()
        }
    }

    private var textColor: Color {
        message.role == .user ? .white : Color(hex: 0x1F2B45)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        switch message.role {
        case .system:
            Color(hex: 0xF7FAFF)
        case .user:
            LinearGradient(
                colors: [Color(hex: 0x3B82F6), Color(hex: 0x2563EB)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .assistant:
            Color.white
        }
    }

    private var bubbleShape: UnevenRoundedRectangle {
        if message.role == .user {
            return UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 16,
                bottomTrailingRadius: 16,
                topTrailingRadius: 4,
                style: .continuous
            )
        }

        return UnevenRoundedRectangle(
            topLeadingRadius: 4,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: 16,
            style: .continuous
        )
    }
}

private struct ChatWelcomeBubble: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            QiheAssistantAvatar(size: 32)

            Text("你好，我是小契。告诉我合同需求或想确认的问题，我会根据内容继续协助你。")
                .font(QiheFont.body(size: 14))
                .lineSpacing(3)
                .foregroundStyle(Color(hex: 0x1F2B45))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color.white)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 16,
                        bottomTrailingRadius: 16,
                        topTrailingRadius: 16,
                        style: .continuous
                    )
                )
                .shadow(color: Color(hex: 0x2563EB).opacity(0.08), radius: 8, x: 0, y: 3)

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ChatActionRecommendation: Equatable {
    enum Action: Equatable {
        case enter(ContractMode)
        case choose([ContractMode])
    }

    let action: Action
    let prefill: String
}

private struct ChatRecommendationActions: View {
    let recommendation: ChatActionRecommendation
    var isDisabled = false
    let onSelectMode: (ContractMode) -> Void

    @ViewBuilder
    var body: some View {
        switch recommendation.action {
        case let .choose(modes):
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(modes, id: \.self) { mode in
                        modeChoiceButton(mode)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(modes, id: \.self) { mode in
                        modeChoiceButton(mode)
                    }
                }
            }
        case let .enter(mode):
            QihePrimaryButton(
                title: mode.enterTitle,
                systemImage: mode.systemImage,
                isDisabled: isDisabled
            ) {
                onSelectMode(mode)
            }
        }
    }

    private func modeChoiceButton(_ mode: ContractMode) -> some View {
        QiheSecondaryButton(
            title: mode.label,
            systemImage: mode.systemImage,
            isDisabled: isDisabled
        ) {
            onSelectMode(mode)
        }
    }
}

private struct TypingIndicator: View {
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            QiheAssistantAvatar(size: 32)

            HStack(spacing: 8) {
                ProgressView()
                    .tint(Color(hex: 0x2563EB))

                Text("小契正在整理回复")
                    .font(QiheFont.body(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: 0x64748B))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 16,
                    bottomTrailingRadius: 16,
                    topTrailingRadius: 16,
                    style: .continuous
                )
            )
            .shadow(color: Color(hex: 0x2563EB).opacity(0.08), radius: 8, x: 0, y: 3)

            Spacer(minLength: 48)
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

    var enterTitle: String {
        switch self {
        case .review:
            return "进入合同审查"
        case .generate:
            return "进入合同生成"
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
