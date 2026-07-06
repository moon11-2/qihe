import SwiftUI

struct ReviewInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var extraInfo = ""
    @State private var isAdditionalInfoExpanded = false
    @State private var contractType = ""
    @State private var userRole = ""
    @State private var focusAreas = ""
    @State private var hasMigratedExtraInfo = false
    @State private var attachment: UploadedFile?
    @State private var isFileImporterPresented = false
    @State private var isUploading = false
    @State private var isRunning = false
    @State private var reviewTask: Task<Void, Never>?
    @State private var activeReviewToken: UUID?
    @State private var errorMessage: String?
    @State private var lastImportedURL: URL?
    private let linedTextLineHeight: CGFloat = 28

    init(prefill: String?, initialAttachment: UploadedFile? = nil) {
        _text = State(initialValue: prefill ?? "")
        _attachment = State(initialValue: initialAttachment)
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()
                .onTapGesture {
                    QiheKeyboard.dismiss()
                }

            ScrollView {
                VStack(spacing: 14) {
                    formTitle

                    if let errorMessage {
                        ErrorBanner(message: errorMessage, retryTitle: retryTitle) {
                            retry()
                        }
                    }

                    textInput
                    uploadSlot

                    if shouldUseUploadedFileAsPrimary && hasText {
                        priorityNotice
                    }

                    additionalInfoSection

                    PaperCard(padding: 14) {
                        VStack(spacing: 12) {
                            ProcessNode(
                                title: "解析文本",
                                detail: attachment != nil ? "将优先按上传文件全文审查。" : "可粘贴合同全文，或上传文件。",
                                isDone: hasText || attachment != nil
                            )
                            ProcessNode(
                                title: "识别主体信息",
                                detail: attachment == nil ? "上传文件后可辅助识别主体信息。" : "已上传 \(attachment?.filename ?? "合同文件")。",
                                isDone: attachment != nil
                            )
                            ProcessNode(
                                title: "条款比对",
                                detail: "提交后生成风险、法条依据与修订建议。",
                                isActive: isRunning
                            )
                            ProcessNode(
                                title: "出具报告",
                                detail: "结果页默认进入风险报告。",
                                isDone: false
                            )
                        }
                    }

                    reviewActionArea

                    Text("AI 辅助审查，不构成法律意见")
                        .font(QiheFont.caption(size: 11))
                        .foregroundStyle(QiheColor.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                }
                .padding(20)
            }
            .qiheScrollDismissesKeyboard()
        }
        .navigationTitle("合同审查")
        .qiheInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .qiheTopTrailing) {
                Button {
                    guard requireSignIn() else {
                        return
                    }
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
        .onAppear {
            migrateExtraInfoIfNeeded()
        }
    }

    private var formTitle: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("合同审查")
                .font(QiheFont.title(size: 27))
                .foregroundStyle(QiheColor.ink)

            Text("上传或粘贴合同，生成风险报告与修改建议。")
                .font(QiheFont.body(size: 13))
                .foregroundStyle(QiheColor.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var textInput: some View {
        PaperCard(padding: 14) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(QiheFont.body(size: 14))
                    .lineSpacing(10)
                    .foregroundStyle(QiheColor.inkSoft)
                    .frame(minHeight: 158)
                    .scrollContentBackground(.hidden)
                    .disabled(isRunning)

                if text.isEmpty {
                    Text("粘贴合同文本")
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.muted)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
            }
            .background(
                LinedPaperBackground(lineHeight: linedTextLineHeight)
                    .opacity(0.72)
            )
        }
    }

    @ViewBuilder
    private var uploadSlot: some View {
        if let attachment {
            VStack(spacing: 10) {
                uploadSummary(
                    systemImage: "doc.text",
                    title: attachment.filename,
                    detail: uploadDetail
                )

                HStack(spacing: 10) {
                    Button {
                        guard requireSignIn() else {
                            return
                        }
                        isFileImporterPresented = true
                    } label: {
                        Label("更换文件", systemImage: "arrow.triangle.2.circlepath")
                            .font(QiheFont.body(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .foregroundStyle(QiheColor.navy)
                    .background(QiheColor.navySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(isUploading || isRunning)

                    Button {
                        removeAttachment()
                    } label: {
                        Label("移除附件", systemImage: "trash")
                            .font(QiheFont.body(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .foregroundStyle(isUploading || isRunning ? QiheColor.muted : QiheColor.seal)
                    .background(isUploading || isRunning ? QiheColor.line : QiheColor.sealSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(isUploading || isRunning)
                }
            }
        } else {
            Button {
                guard requireSignIn() else {
                    return
                }
                isFileImporterPresented = true
            } label: {
                uploadSummary(
                    systemImage: "doc.badge.plus",
                    title: "上传 PDF / Word / TXT",
                    detail: uploadDetail
                )
            }
            .buttonStyle(.plain)
            .disabled(isUploading || isRunning)
        }
    }

    private func uploadSummary(systemImage: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(QiheColor.navy)

            Text(title)
                .font(QiheFont.body(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(detail)
                .font(QiheFont.caption(size: 12))
                .foregroundStyle(QiheColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 14)
        .background(QiheColor.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(QiheColor.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }

    private var additionalInfoSection: some View {
        PaperCard(padding: 14) {
            DisclosureGroup(isExpanded: $isAdditionalInfoExpanded) {
                VStack(spacing: 10) {
                    metadataField(
                        title: "合同类型",
                        placeholder: "如：房屋租赁、服务、买卖",
                        text: $contractType
                    )
                    metadataField(
                        title: "我的立场",
                        placeholder: "如：甲方、乙方、承租人",
                        text: $userRole
                    )
                    metadataField(
                        title: "关注重点",
                        placeholder: "如：付款、违约责任、争议解决",
                        text: $focusAreas,
                        lineLimit: 1...3
                    )
                }
                .padding(.top, 10)
            } label: {
                HStack(spacing: 8) {
                    Text("更多信息")
                        .font(QiheFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)

                    QiheStatusPill(
                        text: "可选",
                        color: QiheColor.muted,
                        background: QiheColor.paperDeep
                    )

                    if hasReviewMetadata {
                        QiheStatusPill(
                            text: "已填写",
                            color: QiheColor.navy,
                            background: QiheColor.navySoft
                        )
                    }
                }
            }
            .disabled(isRunning)
        }
    }

    private func metadataField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        lineLimit: ClosedRange<Int> = 1...1
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.muted)

            TextField(placeholder, text: text, axis: .vertical)
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .lineLimit(lineLimit)
                .padding(10)
                .background(QiheColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .disabled(isRunning)
        }
    }

    @ViewBuilder
    private var reviewActionArea: some View {
        VStack(spacing: 10) {
            QihePrimaryButton(
                title: "开始审查",
                systemImage: "doc.text.magnifyingglass",
                isLoading: isRunning,
                isDisabled: !hasInput || isUploading
            ) {
                startReview()
            }

            if isRunning {
                QiheSecondaryButton(title: "取消", systemImage: "xmark.circle") {
                    cancelReview()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var priorityNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.navy)

            Text("已上传文件，本次将按文件全文审查。")
                .font(QiheFont.body(size: 13))
                .foregroundStyle(QiheColor.navy)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.navySoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var uploadDetail: String {
        if isUploading {
            return "上传中"
        }
        if attachment != nil {
            return "已上传，将按文件审查"
        }
        return "20MB 以内"
    }

    private var hasText: Bool {
        !text.trimmedForInput.isEmpty
    }

    private var shouldUseUploadedFileAsPrimary: Bool {
        attachment != nil
    }

    private var requestText: String? {
        guard !shouldUseUploadedFileAsPrimary else {
            return nil
        }
        return text.trimmedForInput.nilIfBlank
    }

    private var requestFile: UploadedFile? {
        attachment
    }

    private var hasReviewMetadata: Bool {
        contractType.nilIfBlank != nil
            || userRole.nilIfBlank != nil
            || focusAreas.nilIfBlank != nil
    }

    private var reviewMetadata: [String: JSONValue] {
        var metadata: [String: JSONValue] = [:]
        if let contractType = contractType.nilIfBlank {
            metadata["contract_type"] = .string(contractType)
        }
        if let userRole = userRole.nilIfBlank {
            metadata["user_role"] = .string(userRole)
            metadata["role"] = .string(userRole)
        }
        if let focusAreas = focusAreas.nilIfBlank {
            metadata["focus_areas"] = .string(focusAreas)
        }
        return metadata
    }

    private var hasInput: Bool {
        hasText || attachment != nil
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
            errorMessage = error.qiheDisplayMessage
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
        errorMessage = nil
        attachment = nil
        defer { isUploading = false }

        do {
            attachment = try await appState.apiClient.uploadFile(from: url)
        } catch {
            errorMessage = error.qiheDisplayMessage
        }
    }

    private func removeAttachment() {
        attachment = nil
        lastImportedURL = nil
        errorMessage = nil
    }

    private func startReview() {
        guard requireSignIn() else {
            return
        }
        guard hasInput, !isRunning else {
            return
        }
        QiheKeyboard.dismiss()
        migrateExtraInfoIfNeeded()
        let token = UUID()
        activeReviewToken = token
        isRunning = true
        errorMessage = nil
        let task = Task {
            await runReview(token: token)
        }
        reviewTask = task
    }

    private func cancelReview() {
        reviewTask?.cancel()
        reviewTask = nil
        activeReviewToken = nil
        isRunning = false
    }

    private func runReview(token: UUID) async {
        let currentRequestText = requestText
        let currentRequestFile = requestFile
        let currentAttachment = attachment
        let currentMetadata = reviewMetadata

        defer {
            if activeReviewToken == token {
                isRunning = false
                reviewTask = nil
                activeReviewToken = nil
            }
        }

        do {
            var result = try await runReviewRequest(
                text: currentRequestText,
                file: currentRequestFile,
                metadata: currentMetadata
            )
            try Task.checkCancellation()
            guard activeReviewToken == token else {
                return
            }
            let source = ContractSource(
                textPreview: result.source?.textPreview ?? currentRequestText?.truncated(to: 240),
                fileId: result.source?.fileId ?? currentRequestFile?.fileId,
                filename: result.source?.filename ?? currentRequestFile?.filename,
                originalText: result.source?.originalText ?? currentRequestText
            )
            result.source = source
            let id = historyStore.saveReview(
                requestText: currentRequestText ?? "",
                attachment: currentAttachment,
                result: result
            )
            appState.path.append(.reviewResult(recordId: id))
        } catch {
            guard activeReviewToken == token else {
                return
            }
            if isCancellation(error) || Task.isCancelled {
                return
            }
            if currentRequestFile != nil, currentRequestText == nil {
                attachment = nil
                errorMessage = "文件状态可能已失效，请重新上传后再审查。"
            } else {
                errorMessage = error.qiheDisplayMessage
            }
        }
    }

    private func runReviewRequest(
        text: String?,
        file: UploadedFile?,
        metadata: [String: JSONValue]
    ) async throws -> ReviewResult {
        try await appState.apiClient.runReview(
            text: text,
            file: file,
            metadata: metadata
        )
    }

    private func migrateExtraInfoIfNeeded() {
        guard !hasMigratedExtraInfo else {
            return
        }
        defer { hasMigratedExtraInfo = true }
        guard let legacyText = extraInfo.nilIfBlank else {
            return
        }

        let draft = parseLegacyExtraInfo(legacyText)
        if contractType.nilIfBlank == nil, let value = draft.contractType {
            contractType = value
        }
        if userRole.nilIfBlank == nil, let value = draft.userRole {
            userRole = value
        }
        if focusAreas.nilIfBlank == nil {
            focusAreas = draft.focusAreas ?? legacyText
        }
        extraInfo = ""
        if hasReviewMetadata {
            isAdditionalInfoExpanded = true
        }
    }

    private func parseLegacyExtraInfo(_ value: String) -> ReviewMetadataDraft {
        var draft = ReviewMetadataDraft()
        var unlabeledLines: [String] = []
        var hasLabeledValue = false

        for line in value.components(separatedBy: .newlines) {
            guard let cleanedLine = line.nilIfBlank else {
                continue
            }
            guard let separator = cleanedLine.firstIndex(where: { $0 == ":" || $0 == "：" }) else {
                unlabeledLines.append(cleanedLine)
                continue
            }

            let label = String(cleanedLine[..<separator]).trimmedForInput
            let contentStart = cleanedLine.index(after: separator)
            guard let content = String(cleanedLine[contentStart...]).nilIfBlank else {
                continue
            }

            hasLabeledValue = true
            let normalizedLabel = label
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "_", with: "")
                .lowercased()

            if normalizedLabel.contains("合同类型") || normalizedLabel.contains("contracttype") {
                draft.contractType = content
            } else if normalizedLabel.contains("我的立场")
                || normalizedLabel.contains("立场")
                || normalizedLabel.contains("身份")
                || normalizedLabel.contains("role") {
                draft.userRole = content
            } else if normalizedLabel.contains("关注")
                || normalizedLabel.contains("重点")
                || normalizedLabel.contains("focus") {
                draft.focusAreas = content
            } else {
                unlabeledLines.append(cleanedLine)
            }
        }

        if let focusText = unlabeledLines.joined(separator: "\n").nilIfBlank, draft.focusAreas == nil {
            draft.focusAreas = focusText
        }
        guard !hasLabeledValue else {
            return draft
        }

        let pieces = value
            .components(separatedBy: CharacterSet(charactersIn: ",，;；"))
            .compactMap(\.nilIfBlank)
        guard pieces.count >= 3 else {
            return draft
        }
        draft.contractType = draft.contractType ?? pieces[0]
        draft.userRole = draft.userRole ?? pieces[1]
        draft.focusAreas = draft.focusAreas ?? pieces.dropFirst(2).joined(separator: "，")
        return draft
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let urlError = error as? URLError {
            return urlError.code == .cancelled
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func retry() {
        if let lastImportedURL, attachment == nil {
            Task {
                await upload(lastImportedURL)
            }
        } else if hasInput {
            startReview()
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
}

private struct ReviewMetadataDraft {
    var contractType: String?
    var userRole: String?
    var focusAreas: String?
}

private struct LinedPaperBackground: View {
    var lineHeight: CGFloat = 28

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                var y = lineHeight
                while y < proxy.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    y += lineHeight
                }
            }
            .stroke(QiheColor.line, lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}
