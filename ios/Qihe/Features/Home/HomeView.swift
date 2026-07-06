import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var healthState: HealthState = .checking
    @State private var prompt = ""
    @State private var uploadedFile: UploadedFile?
    @State private var isFileImporterPresented = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @FocusState private var isPromptFocused: Bool

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()
                .onTapGesture {
                    isPromptFocused = false
                    QiheKeyboard.dismiss()
                }

            ScrollView {
                VStack(spacing: 20) {
                    brandTopBar
                    heroStatement
                    chatEntry
                    uploadRecommendation
                    coreActions
                    recentRecords
                    healthLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, QiheLayout.rootTabBottomInset)
            }
            .qiheScrollDismissesKeyboard()
        }
        .qiheInlineNavigationTitle()
        .task {
            await checkHealth()
        }
        .refreshable {
            await checkHealth()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: QiheDocumentValidator.allowedTypes
        ) { result in
            handleFileImport(result)
        }
    }

    private var brandTopBar: some View {
        HStack(alignment: .center) {
            QiheBrandLockup(markSize: 36, titleSize: 22)

            Spacer(minLength: 12)

            QiheSloganLockup(compact: true)
        }
        .padding(.top, 4)
    }

    private var heroStatement: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今天要处理哪份合同？")
                .font(QiheFont.title(size: 27))
                .foregroundStyle(QiheColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text("输入、上传，或直接选择审查和生成。")
                .font(QiheFont.body(size: 13))
                .foregroundStyle(QiheColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var chatEntry: some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 8) {
                    QiheLogoMark(size: 20)

                    Text("契合")
                        .font(QiheFont.body(size: 13, weight: .semibold))
                        .foregroundStyle(QiheColor.navy)

                    Spacer(minLength: 0)
                }

                TextField("输入合同内容，或描述你想生成的合同……", text: $prompt, axis: .vertical)
                    .font(QiheFont.body(size: 16))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(2...5)
                    .frame(minHeight: 60, alignment: .topLeading)
                    .focused($isPromptFocused)

                HStack {
                    Text(uploadedFile == nil ? "可粘贴文本，也可上传 PDF / Word / TXT" : "已上传文件，可进入审查")
                        .font(QiheFont.caption(size: 11.5, weight: .medium))
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Spacer()

                    HStack(spacing: 8) {
                        QiheIconCircleButton(
                            systemImage: "plus",
                            accessibilityLabel: "上传文件",
                            size: 34,
                            isLoading: isUploading,
                            isDisabled: isUploading
                        ) {
                            guard requireSignIn() else {
                                return
                            }
                            isFileImporterPresented = true
                        }

                        QiheIconCircleButton(
                            systemImage: "arrow.up",
                            accessibilityLabel: "发送",
                            size: 34,
                            isPrimary: true,
                            isDisabled: !canSendPrompt
                        ) {
                            sendPrompt()
                        }
                    }
                }
            }
        }
    }

    private var coreActions: some View {
        PaperCard(padding: 14) {
            VStack(alignment: .leading, spacing: 14) {
                Text("核心入口")
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)

                HStack(spacing: 12) {
                    Button {
                        guard requireSignIn() else {
                            return
                        }
                        isPromptFocused = false
                        QiheKeyboard.dismiss()
                        appState.path.append(.review(prefill: nil))
                    } label: {
                        Text("合同审查")
                            .font(QiheFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(QiheColor.navy)
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        guard requireSignIn() else {
                            return
                        }
                        isPromptFocused = false
                        QiheKeyboard.dismiss()
                        appState.path.append(.generate(prefill: nil))
                    } label: {
                        Text("合同生成")
                            .font(QiheFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(QiheColor.paper)
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                                    .stroke(QiheColor.lineStrong, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(QiheColor.navy)

                    Text("逐条审查 · 标注法条依据 · 历史仅本地保存")
                        .font(QiheFont.caption(size: 11))
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
    }

    @ViewBuilder
    private var uploadRecommendation: some View {
        if let uploadError {
            ErrorBanner(message: uploadError, retryTitle: nil, retry: nil)
        } else if let uploadedFile {
            PaperCard(padding: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(QiheColor.navy)
                        .frame(width: 34, height: 34)
                        .background(QiheColor.navySoft)
                        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(uploadedFile.filename)
                            .font(QiheFont.body(size: 14, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)
                            .lineLimit(1)

                        Text("已上传，建议进入合同审查")
                            .font(QiheFont.caption(size: 12))
                            .foregroundStyle(QiheColor.muted)
                    }

                    Spacer()

                    Button("审查") {
                        guard requireSignIn() else {
                            return
                        }
                        let file = uploadedFile
                        self.uploadedFile = nil
                        uploadError = nil
                        isPromptFocused = false
                        QiheKeyboard.dismiss()
                        appState.path.append(.review(prefill: nil, attachment: file))
                    }
                    .font(QiheFont.caption(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(QiheColor.navy)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous))
                }
            }
        }
    }

    private var recentRecords: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近记录")
                    .font(QiheFont.title(size: 15))
                    .foregroundStyle(QiheColor.ink)

                Spacer()

                Button("展开") {
                    isPromptFocused = false
                    QiheKeyboard.dismiss()
                    appState.selectedTab = .history
                }
                .font(QiheFont.caption(size: 12, weight: .medium))
                .foregroundStyle(QiheColor.navy)
                .disabled(historyStore.records.isEmpty)
            }
            .padding(.bottom, 8)

            if historyStore.records.isEmpty {
                PaperCard(padding: 14) {
                    EmptyStateView(
                        title: "暂无最近记录",
                        detail: "从对话、审查或生成开始后，本地历史会出现在这里。"
                    )
                    .padding(.vertical, 2)
                }
            } else {
                PaperCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(historyStore.records.prefix(3))) { record in
                            HomeRecentRecordRow(record: record) {
                                appState.openHistoryRecord(record)
                            }
                        }
                    }
                }
            }
        }
    }

    private var healthLine: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(healthState.color)
                .frame(width: 7, height: 7)

            Text(healthState.compactDetail(baseURL: appState.apiClient.baseURL))
                .font(QiheFont.caption(size: 11))
                .foregroundStyle(QiheColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            Button {
                Task {
                    await checkHealth()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(QiheColor.navy)
            .disabled(healthState == .checking)
        }
        .padding(.top, -2)
    }

    private var canSendPrompt: Bool {
        prompt.trimmedForInput.nilIfBlank != nil || uploadedFile != nil
    }

    private func sendPrompt() {
        guard requireSignIn() else {
            return
        }
        let text = prompt.trimmedForInput
        guard !text.isEmpty || uploadedFile != nil else {
            return
        }
        isPromptFocused = false
        QiheKeyboard.dismiss()
        prompt = ""

        if let uploadedFile {
            self.uploadedFile = nil
            appState.path.append(.review(prefill: text.nilIfBlank, attachment: uploadedFile))
        } else {
            appState.path.append(.chat(localRecordId: nil, initialMessage: text))
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            Task {
                await upload(url)
            }
        case let .failure(error):
            uploadError = error.qiheDisplayMessage
        }
    }

    private func upload(_ url: URL) async {
        guard authStore.status.isSignedIn else {
            await MainActor.run {
                openSignIn()
            }
            return
        }
        isUploading = true
        uploadError = nil
        uploadedFile = nil
        defer { isUploading = false }

        do {
            uploadedFile = try await appState.apiClient.uploadFile(from: url)
        } catch {
            uploadError = error.qiheDisplayMessage
        }
    }

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

    private func checkHealth() async {
        healthState = .checking
        do {
            let response = try await appState.apiClient.health()
            healthState = response.status == "ok" ? .online(service: response.service) : .offline(message: "服务状态异常")
        } catch {
            healthState = .offline(message: error.qiheDisplayMessage)
        }
    }
}

private struct HomeRecentRecordRow: View {
    let record: HistoryRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(QiheColor.inkSoft)
                    .frame(width: 34, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title.nilIfBlank ?? "未命名记录")
                        .font(QiheFont.body(size: 13.5, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(1)

                    Text(Self.dateFormatter.string(from: record.updatedAt))
                        .font(QiheFont.caption(size: 11))
                        .foregroundStyle(QiheColor.muted)
                }

                Spacer()

                Text(stampText)
                    .font(QiheFont.title(size: 10))
                    .foregroundStyle(stampColor)
                    .padding(.horizontal, 8)
                    .frame(minWidth: 42)
                    .frame(height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                            .stroke(stampColor, lineWidth: 1)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QiheColor.line)
                .frame(height: 1)
                .padding(.horizontal, 14)
        }
    }

    private var iconName: String {
        switch record.type {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .review:
            return "doc.text.magnifyingglass"
        case .generate:
            return "doc.text"
        }
    }

    private var stampText: String {
        switch record.type {
        case .chat:
            return "对话"
        case .review:
            return "已审"
        case .generate:
            return "草案"
        }
    }

    private var stampColor: Color {
        switch record.type {
        case .chat:
            return QiheColor.navy
        case .review:
            return QiheColor.pine
        case .generate:
            return QiheColor.amber
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum HealthState: Equatable {
    case checking
    case online(service: String)
    case offline(message: String)

    var color: Color {
        switch self {
        case .checking:
            return QiheColor.amber
        case .online:
            return QiheColor.pine
        case .offline:
            return QiheColor.seal
        }
    }

    func compactDetail(baseURL _: URL) -> String {
        switch self {
        case .checking:
            return "正在连接云端服务"
        case .online:
            return "云端服务已连接"
        case let .offline(message):
            return "离线可查看本地历史 · \(message)"
        }
    }
}
