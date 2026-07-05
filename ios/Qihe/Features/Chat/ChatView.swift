import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var appState: AppState
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
            QiheColor.paper.ignoresSafeArea()
                .onTapGesture {
                    isInputFocused = false
                    QiheKeyboard.dismiss()
                }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 14) {
                        processCard

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
        .navigationTitle("过程对话")
        .qiheInlineNavigationTitle()
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
        PaperCard {
            EmptyStateView(
                title: "开始过程对话",
                detail: "输入合同内容、审查问题或生成需求；契合会推荐进入审查或生成。"
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
                    .focused($isInputFocused)
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

    private var canSend: Bool {
        !isSending && input.trimmedForInput.nilIfBlank != nil
    }

    private var latestUserInput: String? {
        messages.reversed()
            .first { $0.role == .user }?
            .content
            .nilIfBlank
    }

    private var nextStepDetail: String {
        if isSending {
            return "正在等待后端回复"
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

        submitUserText(text)
    }

    @MainActor
    private func submitUserText(_ text: String) {
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
    private func persistMessages() {
        guard !messages.isEmpty else {
            return
        }
        recordId = historyStore.saveChat(recordId: recordId, messages: messages)
    }

    @MainActor
    private func openMode(_ mode: ContractMode, prefill recommendedPrefill: String? = nil) {
        guard let prefill = recommendedPrefill?.nilIfBlank ?? latestUserInput else {
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
                primaryRoute: route,
                modes: [route, route.alternative],
                prefill: prefill
            )
        }

        let responseModes = orderedModes(from: modes(from: response))
        guard !responseModes.isEmpty else {
            return nil
        }

        return ChatActionRecommendation(
            primaryRoute: responseModes.count == 1 ? responseModes[0] : nil,
            modes: responseModes,
            prefill: prefill
        )
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
}

private struct ChatBubble: View {
    let message: ChatMessage
    var recommendation: ChatActionRecommendation?
    var isActionDisabled = false
    let onSelectMode: (ContractMode) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 54)
            }

            VStack(alignment: alignment, spacing: 6) {
                Text(roleTitle)
                    .font(QiheFont.caption(size: 11, weight: .semibold))
                    .foregroundStyle(titleColor)

                VStack(alignment: .leading, spacing: 10) {
                    Text(message.content)
                        .font(QiheFont.body(size: 15))
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

private struct ChatActionRecommendation: Equatable {
    let primaryRoute: ContractMode?
    let modes: [ContractMode]
    let prefill: String

    var showsChoicePair: Bool {
        primaryRoute == nil && Set(modes) == Set([.review, .generate])
    }

    var primaryMode: ContractMode? {
        primaryRoute ?? modes.first
    }

    var secondaryMode: ContractMode? {
        if let primaryRoute {
            return primaryRoute.alternative
        }
        guard modes.count > 1 else {
            return nil
        }
        return modes[1]
    }
}

private struct ChatRecommendationActions: View {
    let recommendation: ChatActionRecommendation
    var isDisabled = false
    let onSelectMode: (ContractMode) -> Void

    var body: some View {
        if recommendation.showsChoicePair {
            HStack(spacing: 8) {
                ForEach(recommendation.modes, id: \.self) { mode in
                    QiheSecondaryButton(
                        title: mode.label,
                        systemImage: mode.systemImage,
                        isDisabled: isDisabled
                    ) {
                        onSelectMode(mode)
                    }
                }
            }
        } else if let primaryMode = recommendation.primaryMode {
            VStack(spacing: 8) {
                QihePrimaryButton(
                    title: primaryMode.enterTitle,
                    systemImage: primaryMode.systemImage,
                    isDisabled: isDisabled
                ) {
                    onSelectMode(primaryMode)
                }

                if let secondaryMode = recommendation.secondaryMode {
                    QiheSecondaryButton(
                        title: secondaryMode.switchTitle,
                        systemImage: secondaryMode.systemImage,
                        isDisabled: isDisabled
                    ) {
                        onSelectMode(secondaryMode)
                    }
                }
            }
        }
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

    var enterTitle: String {
        switch self {
        case .review:
            return "进入审查"
        case .generate:
            return "进入生成"
        }
    }

    var switchTitle: String {
        switch self {
        case .review:
            return "改为审查"
        case .generate:
            return "改为生成"
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

    var alternative: ContractMode {
        switch self {
        case .review:
            return .generate
        case .generate:
            return .review
        }
    }
}
