import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var healthState: HealthState = .checking
    @State private var prompt = ""
    @State private var uploadedFile: UploadedFile?
    @State private var isFileImporterPresented = false
    @State private var isUploading = false
    @State private var uploadError: String?

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    topBar
                    hero
                    chatEntry
                    uploadRecommendation
                    shortcutEntries
                    trustLine
                    recentRecords
                    healthLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
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

    private var topBar: some View {
        HStack {
            QiheIconCircleButton(
                systemImage: "sidebar.left",
                accessibilityLabel: "本地历史",
                size: 34
            ) {
                appState.isHistoryPresented = true
            }

            Spacer()

            QiheIconCircleButton(
                systemImage: "square.and.pencil",
                accessibilityLabel: "新建对话",
                size: 34
            ) {
                prompt = ""
                uploadedFile = nil
                uploadError = nil
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            SealMark(size: 64)
                .rotationEffect(.degrees(-3))

            VStack(spacing: 4) {
                Text("契合")
                    .font(QiheFont.title(size: 24))
                    .foregroundStyle(QiheColor.ink)

                Text("AI 合同审查与生成助手")
                    .font(QiheFont.caption(size: 11, weight: .medium))
                    .foregroundStyle(QiheColor.muted.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 0)
    }

    private var chatEntry: some View {
        PaperCard(padding: 14) {
            VStack(spacing: 10) {
                TextField("输入合同内容，或描述你想生成的合同……", text: $prompt, axis: .vertical)
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(2...5)
                    .frame(minHeight: 44, alignment: .topLeading)

                HStack {
                    Text("合同助手")
                        .font(QiheFont.caption(size: 11.5, weight: .medium))
                        .foregroundStyle(QiheColor.inkSoft)
                        .padding(.horizontal, 11)
                        .frame(height: 26)
                        .background(QiheColor.card)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(QiheColor.lineStrong, lineWidth: 1))

                    Spacer()

                    HStack(spacing: 8) {
                        QiheIconCircleButton(
                            systemImage: "plus",
                            accessibilityLabel: "上传文件",
                            size: 34,
                            isLoading: isUploading,
                            isDisabled: isUploading
                        ) {
                            isFileImporterPresented = true
                        }

                        QiheIconCircleButton(
                            systemImage: "arrow.up",
                            accessibilityLabel: "发送",
                            size: 34,
                            isPrimary: true,
                            isDisabled: prompt.trimmedForInput.isEmpty
                        ) {
                            sendPrompt()
                        }
                    }
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
                        appState.path.append(.review(prefill: nil, attachment: uploadedFile))
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

    private var shortcutEntries: some View {
        HStack(spacing: 12) {
            HomeQuickEntry(title: "合同审查", seal: "審", detail: "粘贴文本或上传\nPDF / Word / TXT") {
                appState.path.append(.review(prefill: nil))
            }

            HomeQuickEntry(title: "合同生成", seal: "擬", detail: "描述需求\n生成合同草案", accent: QiheColor.ink) {
                appState.path.append(.generate(prefill: nil))
            }
        }
    }

    private var trustLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(QiheColor.navy)

            Text("逐条审查 · 标注法条依据 · 历史仅本地保存")
                .font(QiheFont.caption(size: 10.5))
                .foregroundStyle(QiheColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, -4)
    }

    private var recentRecords: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("最近记录")
                    .font(QiheFont.title(size: 15))
                    .foregroundStyle(QiheColor.ink)

                Spacer()

                Button("展开") {
                    appState.isHistoryPresented = true
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
        .padding(.top, 2)
    }

    private func sendPrompt() {
        let text = prompt.trimmedForInput
        guard !text.isEmpty else {
            return
        }
        prompt = ""
        appState.path.append(.chat(localRecordId: nil, initialMessage: text))
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case let .success(url):
            Task {
                await upload(url)
            }
        case let .failure(error):
            uploadError = error.localizedDescription
        }
    }

    private func upload(_ url: URL) async {
        isUploading = true
        uploadError = nil
        defer { isUploading = false }

        do {
            uploadedFile = try await appState.apiClient.uploadFile(from: url)
        } catch {
            uploadError = error.localizedDescription
        }
    }

    private func checkHealth() async {
        healthState = .checking
        do {
            let response = try await appState.apiClient.health()
            healthState = response.status == "ok" ? .online(service: response.service) : .offline(message: "服务状态异常")
        } catch {
            healthState = .offline(message: error.localizedDescription)
        }
    }
}

private struct HomeQuickEntry: View {
    let title: String
    let seal: String
    let detail: String
    var accent: Color = QiheColor.navy
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(seal)
                        .font(QiheFont.title(size: 12))
                        .foregroundStyle(QiheColor.seal)
                    Spacer()
                }

                Text(title)
                    .font(QiheFont.title(size: 16))
                    .foregroundStyle(QiheColor.ink)

                Text(detail)
                    .font(QiheFont.caption(size: 11.5))
                    .foregroundStyle(QiheColor.muted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(accent)
                    .frame(height: 3)
                    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            }
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                    .stroke(QiheColor.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
                    .frame(width: 30, height: 35)

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
                    .padding(.horizontal, 7)
                    .frame(height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                            .stroke(stampColor, lineWidth: 1)
                    )
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QiheColor.line)
                .frame(height: 1)
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
            return "審畢"
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

    func compactDetail(baseURL: URL) -> String {
        switch self {
        case .checking:
            return "连接中 · \(baseURL.absoluteString)"
        case let .online(service):
            return "\(service) 已连接"
        case let .offline(message):
            return "离线可看本地历史 · \(message)"
        }
    }
}
