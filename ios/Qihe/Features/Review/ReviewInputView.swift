import SwiftUI
import UniformTypeIdentifiers

struct ReviewInputView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var text: String
    @State private var extraInfo = ""
    @State private var isAdditionalInfoExpanded = false
    @State private var contractType = ""
    @State private var userRole = ""
    @AppStorage("review.perspective") private var perspectiveRaw: String = ReviewPerspective.neutral.rawValue
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
    @State private var attachmentCharacterCount: Int?
    @State private var pendingUploadFilename: String?
    private let contractTypeOptions = ["房屋租赁", "劳动合同", "买卖合同", "服务协议"]
    private let focusAreaOptions = ["付款", "违约责任", "解除", "争议解决"]

    init(prefill: String?, initialAttachment: UploadedFile? = nil) {
        _text = State(initialValue: prefill ?? "")
        _attachment = State(initialValue: initialAttachment)
    }

    var body: some View {
        ZStack {
            QiheColor.pageBackgroundGradient.ignoresSafeArea()
                .onTapGesture {
                    QiheKeyboard.dismiss()
                }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let errorMessage {
                        ErrorBanner(message: errorMessage, retryTitle: retryTitle) {
                            retry()
                        }
                    }

                    uploadSlot
                    pasteDivider
                    textInput

                    if shouldUseUploadedFileAsPrimary && hasText {
                        priorityNotice
                    }

                    perspectiveSection
                    contractTypeSection
                    focusAreaSection
                    additionalInfoSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 116)
            }
            .qiheScrollDismissesKeyboard()
        }
        .navigationTitle("审查合同")
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
            allowedContentTypes: ReviewDocumentValidator.allowedTypes
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            migrateExtraInfoIfNeeded()
            if attachmentCharacterCount == nil {
                attachmentCharacterCount = QiheUploadPresentationCache.characterCount(for: attachment)
            }
        }
        .safeAreaInset(edge: .bottom) {
            reviewActionArea
        }
    }

    private var perspectiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("您的立场")

            HStack(spacing: 8) {
                ForEach(ReviewPerspective.allCases, id: \.self) { perspective in
                    ReviewPerspectiveButton(
                        title: perspectiveTitle(for: perspective),
                        isSelected: reviewPerspective == perspective,
                        isDisabled: isRunning
                    ) {
                        perspectiveRaw = perspective.rawValue
                    }
                }
            }
        }
    }

    private var contractTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("合同类型")

            ReviewInputFlowLayout(spacing: 7) {
                ForEach(contractTypeOptions, id: \.self) { option in
                    ReviewInputChip(
                        title: option,
                        systemImage: isContractTypeSelected(option) ? "checkmark" : nil,
                        isSelected: isContractTypeSelected(option),
                        isDisabled: isRunning
                    ) {
                        toggleContractType(option)
                    }
                }
            }

            metadataTextField(
                placeholder: "自定义合同类型",
                text: $contractType
            )
        }
    }

    private var focusAreaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("重点审查方向")

            ReviewInputFlowLayout(spacing: 7) {
                ForEach(focusAreaOptions, id: \.self) { option in
                    ReviewInputChip(
                        title: option,
                        systemImage: isFocusAreaSelected(option) ? "checkmark" : nil,
                        isSelected: isFocusAreaSelected(option),
                        isDisabled: isRunning
                    ) {
                        toggleFocusArea(option)
                    }
                }
            }

            metadataTextField(
                placeholder: "自定义重点，多个可用顿号或逗号分隔",
                text: $focusAreas,
                lineLimit: 1...2
            )
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(QiheFont.body(size: 14))
                    .lineSpacing(6)
                    .foregroundStyle(QiheColor.inkSoft)
                    .frame(minHeight: 108)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .disabled(isRunning)

                if text.isEmpty {
                    Text("粘贴合同完整文本内容…")
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.muted)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(QiheColor.card.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(QiheColor.glassStroke.opacity(0.78), lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 8, x: 0, y: 3)
        }
    }

    private var pasteDivider: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(QiheColor.glassStroke.opacity(0.72))
                .frame(height: 1)

            Text("或粘贴合同原文")
                .font(QiheFont.caption(size: 11.5))
                .foregroundStyle(QiheColor.muted.opacity(0.78))
                .fixedSize()

            Rectangle()
                .fill(QiheColor.glassStroke.opacity(0.72))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var uploadSlot: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isUploading {
                uploadSummary(
                    systemImage: "arrow.up.doc",
                    title: pendingUploadFilename ?? "合同文件",
                    detail: "正在上传并解析文件…",
                    state: .uploading
                )
            }

            if let attachment {
                VStack(spacing: 10) {
                    uploadSummary(
                        systemImage: "checkmark.circle.fill",
                        title: attachment.filename,
                        detail: uploadDetail,
                        state: .succeeded
                    )

                    HStack(spacing: 10) {
                        uploadControlButton(
                            title: "更换文件",
                            systemImage: "arrow.triangle.2.circlepath",
                            foreground: QiheColor.navy,
                            background: QiheColor.navySoft,
                            isDisabled: isUploading || isRunning
                        ) {
                            guard requireSignIn() else {
                                return
                            }
                            isFileImporterPresented = true
                        }

                        uploadControlButton(
                            title: "移除附件",
                            systemImage: "trash",
                            foreground: QiheColor.seal,
                            background: QiheColor.sealSoft,
                            isDisabled: isUploading || isRunning
                        ) {
                            removeAttachment()
                        }
                    }
                }
            } else if !isUploading {
                Button {
                    guard requireSignIn() else {
                        return
                    }
                    isFileImporterPresented = true
                } label: {
                    uploadSummary(
                        systemImage: "doc.badge.plus",
                        title: "上传 PDF、DOCX 或 TXT 文件",
                        detail: uploadDetail,
                        state: .idle
                    )
                }
                .buttonStyle(.plain)
                .disabled(isUploading || isRunning)
            }
        }
    }

    private func uploadSummary(
        systemImage: String,
        title: String,
        detail: String,
        state: ReviewUploadPresentationState
    ) -> some View {
        Group {
            if state == .idle {
                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(QiheColor.primaryGradient)

                        Image(systemName: "arrow.up.doc")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 52, height: 52)
                    .shadow(color: QiheColor.shadowBlue.opacity(0.72), radius: 12, x: 0, y: 6)

                    Text(title)
                        .font(QiheFont.body(size: 16, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)

                    Text(detail)
                        .font(QiheFont.caption(size: 12))
                        .foregroundStyle(QiheColor.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
            } else {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(state.iconBackground)

                        if state == .uploading {
                            ProgressView()
                                .tint(QiheColor.brandBlue)
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(state.iconForeground)
                        }
                    }
                    .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(QiheFont.body(size: 15, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.78)

                        Text(detail)
                            .font(QiheFont.caption(size: 12))
                            .foregroundStyle(QiheColor.muted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    if state == .succeeded {
                        QiheStatusPill(
                            text: "已上传",
                            color: QiheColor.safeGreen,
                            background: QiheColor.safeGreenSoft
                        )
                    } else {
                        QiheStatusPill(
                            text: "上传中",
                            color: QiheColor.brandBlue,
                            background: QiheColor.infoBlueSoft
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, state == .idle ? 25 : 14)
        .background(QiheColor.card.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(QiheColor.brandBlue.opacity(0.42), style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
        )
        .shadow(color: QiheColor.shadowBlue.opacity(0.12), radius: 16, x: 0, y: 7)
    }

    private var additionalInfoSection: some View {
        QiheGlassCard(padding: 12, cornerRadius: QiheRadius.input) {
            DisclosureGroup(isExpanded: $isAdditionalInfoExpanded) {
                metadataField(
                    title: "具体身份",
                    placeholder: "如：承租人、供应商、委托方",
                    text: $userRole
                )
                .padding(.top, 10)
            } label: {
                HStack(spacing: 8) {
                    Text("身份补充")
                        .font(QiheFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)

                    QiheStatusPill(
                        text: "可选",
                        color: QiheColor.muted,
                        background: QiheColor.paperDeep
                    )

                    if userRole.nilIfBlank != nil {
                        QiheStatusPill(
                            text: "已填写",
                            color: QiheColor.navy,
                            background: QiheColor.navySoft
                        )
                    }

                    Spacer(minLength: 0)
                }
            }
            .disabled(isRunning)
            .accentColor(QiheColor.navy)
        }
    }

    private func metadataTextField(
        placeholder: String,
        text: Binding<String>,
        lineLimit: ClosedRange<Int> = 1...1
    ) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(QiheFont.body(size: 14))
            .foregroundStyle(QiheColor.inkSoft)
            .lineLimit(lineLimit)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(QiheColor.card.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(QiheColor.glassStroke, lineWidth: 1)
            )
            .disabled(isRunning)
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

            metadataTextField(
                placeholder: placeholder,
                text: text,
                lineLimit: lineLimit
            )
        }
    }

    @ViewBuilder
    private var reviewActionArea: some View {
        VStack(spacing: 10) {
            ReviewSubmitButton(
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

            if !isRunning {
                Text("小契会按你的立场讲清重点，并给出可采用的修改方案")
                    .font(QiheFont.caption(size: 11))
                    .foregroundStyle(QiheColor.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QiheColor.glassStroke)
                .frame(height: 1)
        }
    }

    private var priorityNotice: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.navy)

            Text("已上传文件，本次将按文件全文审查，粘贴文本不会作为主输入。")
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
        if attachment != nil {
            if let attachmentCharacterCount {
                return "\(attachmentCharacterCount.formatted()) 字符 · 将按文件全文审查"
            }
            return "已上传 · 将按文件全文审查"
        }
        return "PDF、DOCX、TXT · 最大 20MB"
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

    private var reviewPerspective: ReviewPerspective {
        ReviewPerspective(rawValue: perspectiveRaw) ?? .neutral
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
        metadata["review_perspective"] = .string(reviewPerspective.rawValue)
        return metadata
    }

    private var hasInput: Bool {
        hasText || attachment != nil
    }

    private var retryTitle: String? {
        if lastImportedURL != nil {
            return "重试上传"
        }
        if hasInput {
            return "重试"
        }
        return nil
    }

    private var focusAreaTokens: [String] {
        Self.focusTokens(from: focusAreas)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(QiheFont.caption(size: 12.5, weight: .semibold))
            .foregroundStyle(QiheColor.muted)
    }

    private func perspectiveTitle(for perspective: ReviewPerspective) -> String {
        switch perspective {
        case .partyA:
            return "我是甲方"
        case .partyB:
            return "我是乙方"
        case .neutral:
            return "中立角度"
        }
    }

    private func isContractTypeSelected(_ option: String) -> Bool {
        contractType.trimmedForInput == option
    }

    private func toggleContractType(_ option: String) {
        guard !isRunning else {
            return
        }
        contractType = isContractTypeSelected(option) ? "" : option
    }

    private func isFocusAreaSelected(_ option: String) -> Bool {
        focusAreaTokens.contains(option)
    }

    private func toggleFocusArea(_ option: String) {
        guard !isRunning else {
            return
        }
        var tokens = focusAreaTokens
        if let index = tokens.firstIndex(of: option) {
            tokens.remove(at: index)
        } else {
            tokens.append(option)
        }
        focusAreas = tokens.joined(separator: "、")
    }

    private static func focusTokens(from value: String) -> [String] {
        var seen: Set<String> = []
        return value
            .components(separatedBy: CharacterSet(charactersIn: "、,，;；\n"))
            .compactMap(\.nilIfBlank)
            .filter { token in
                guard !seen.contains(token) else {
                    return false
                }
                seen.insert(token)
                return true
            }
    }

    private func uploadControlButton(
        title: String,
        systemImage: String,
        foreground: Color,
        background: Color,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(QiheFont.body(size: 14, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .foregroundStyle(isDisabled ? QiheColor.muted : foreground)
        .background(isDisabled ? QiheColor.line : background)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .buttonStyle(.plain)
        .disabled(isDisabled)
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
        guard ReviewDocumentValidator.allows(url) else {
            errorMessage = "仅支持 PDF、DOCX 和 TXT 文件。"
            return
        }
        isUploading = true
        errorMessage = nil
        pendingUploadFilename = url.lastPathComponent
        let characterCountTask = Task.detached(priority: .utility) {
            QiheLocalDocumentMetrics.characterCount(at: url)
        }
        defer {
            isUploading = false
            pendingUploadFilename = nil
        }

        do {
            let file = try await appState.apiClient.uploadFile(from: url)
            let characterCount = await characterCountTask.value
            attachment = file
            attachmentCharacterCount = characterCount
            QiheUploadPresentationCache.store(characterCount: characterCount, for: file)
            lastImportedURL = nil
        } catch {
            characterCountTask.cancel()
            errorMessage = error.qiheDisplayMessage
        }
    }

    private func removeAttachment() {
        attachment = nil
        attachmentCharacterCount = nil
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
            await runReviewJob(token: token)
        }
        reviewTask = task
    }

    private func cancelReview() {
        reviewTask?.cancel()
        reviewTask = nil
        activeReviewToken = nil
        isRunning = false
    }

    /// 任务四：通过 job 方式提交审查
    private func runReviewJob(token: UUID) async {
        let currentRequestText = requestText
        let currentRequestFile = requestFile
        let currentMetadata = reviewMetadata

        defer {
            if activeReviewToken == token {
                isRunning = false
                reviewTask = nil
                activeReviewToken = nil
            }
        }

        do {
            let jobId = try await appState.apiClient.submitReviewJob(
                text: currentRequestText,
                file: currentRequestFile,
                metadata: currentMetadata
            )
            try Task.checkCancellation()
            guard activeReviewToken == token else { return }

            // 导航到进度页
            appState.path.append(
                .progress(
                    jobId: jobId,
                    mode: .review,
                    requestText: currentRequestText,
                    attachment: currentRequestFile
                )
            )
        } catch {
            guard activeReviewToken == token else { return }
            if isCancellation(error) || Task.isCancelled { return }

            if let apiError = error as? APIClientError,
               apiError.permitsSynchronousContractFallback {
                guard !Task.isCancelled, activeReviewToken == token else { return }

                do {
                    let result = try await appState.apiClient.runReview(
                        text: currentRequestText,
                        file: currentRequestFile,
                        metadata: currentMetadata
                    )
                    try Task.checkCancellation()
                    guard activeReviewToken == token else { return }

                    let recordId = historyStore.saveReview(
                        requestText: currentRequestText ?? "",
                        attachment: currentRequestFile,
                        result: result
                    )
                    appState.path.append(.reviewResult(recordId: recordId))
                } catch {
                    guard activeReviewToken == token else { return }
                    if isCancellation(error) || Task.isCancelled { return }
                    errorMessage = error.qiheDisplayMessage
                }
                return
            }

            errorMessage = error.qiheDisplayMessage
        }
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
        if let lastImportedURL {
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

private enum ReviewUploadPresentationState: Equatable {
    case idle
    case uploading
    case succeeded

    var iconBackground: Color {
        switch self {
        case .idle, .uploading:
            return QiheColor.infoBlueSoft
        case .succeeded:
            return QiheColor.safeGreenSoft
        }
    }

    var iconForeground: Color {
        switch self {
        case .idle, .uploading:
            return QiheColor.brandBlue
        case .succeeded:
            return QiheColor.safeGreen
        }
    }
}

private enum ReviewDocumentValidator {
    static let allowedTypes: [UTType] = [
        .pdf,
        .plainText,
        UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    ]

    private static let allowedExtensions: Set<String> = ["pdf", "docx", "txt"]

    static func allows(_ url: URL) -> Bool {
        allowedExtensions.contains(url.pathExtension.lowercased())
    }
}

private struct ReviewMetadataDraft {
    var contractType: String?
    var userRole: String?
    var focusAreas: String?
}

private struct ReviewInputFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rows(in: width, subviews: subviews)
        return CGSize(width: width, height: rows.last?.maxY ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in rows(in: bounds.width, subviews: subviews) {
            for item in row.items {
                item.subview.place(
                    at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + item.frame.minY),
                    proposal: ProposedViewSize(item.frame.size)
                )
            }
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [FlowRow] {
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                rows.append(FlowRow(items: currentItems, maxY: y + rowHeight))
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
                currentItems = []
            }

            let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
            currentItems.append(FlowItem(subview: subview, frame: frame))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(FlowRow(items: currentItems, maxY: y + rowHeight))
        }

        return rows
    }

    private struct FlowItem {
        let subview: LayoutSubview
        let frame: CGRect
    }

    private struct FlowRow {
        let items: [FlowItem]
        let maxY: CGFloat
    }
}

private struct ReviewPerspectiveButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(QiheFont.body(size: 15, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? QiheColor.navy : QiheColor.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? QiheColor.navySoft : QiheColor.glassFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? QiheColor.navy : QiheColor.glassStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.58 : 1)
    }
}

private struct ReviewSubmitButton: View {
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                }

                Text("开始审查")
                    .lineLimit(1)
            }
            .font(QiheFont.body(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background {
                if isDisabled {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(QiheColor.neutral300)
                } else {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(QiheColor.primaryGradient)
                }
            }
            .shadow(
                color: isDisabled ? .clear : QiheColor.shadowBlue.opacity(0.74),
                radius: 16,
                x: 0,
                y: 7
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel("开始审查")
    }
}

private struct ReviewInputChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                }

                Text(title)
                    .font(QiheFont.caption(size: 12, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(isSelected ? QiheColor.navy : QiheColor.inkSoft)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? QiheColor.navySoft : QiheColor.card.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? QiheColor.navy.opacity(0.25) : QiheColor.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.58 : 1)
    }
}

// MARK: - 合同进度页通用视图（任务四）

/// 审查/生成共用的进度页面，展示任务处理进度和步骤文案。
struct ContractProgressView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var jobPollingStore: JobPollingStore
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let jobId: String
    let mode: ContractMode
    let requestText: String?
    let attachment: UploadedFile?
    let sourceChatRecordId: UUID?

    @State private var cancelled = false
    @State private var spinnerIsAnimating = false
    @SceneStorage("qihe.progress.consumedJobIDs") private var consumedJobIDs = ""
    @ScaledMetric(relativeTo: .body) private var actionMinHeight: CGFloat = 40

    var body: some View {
        ZStack {
            progressBackground

            if mode == .review {
                reviewProgressContent
            } else {
                generateProgressContent
            }
        }
        .navigationTitle(mode == .review ? "审查进度" : "生成进度")
        .qiheInlineNavigationTitle()
        .navigationBarBackButtonHidden(jobPollingStore.isPolling)
        .onAppear {
            spinnerIsAnimating = !accessibilityReduceMotion
            startPollingIfNeeded()
        }
        .onDisappear {
            spinnerIsAnimating = false
            jobPollingStore.stopPolling()
        }
        .onChange(of: accessibilityReduceMotion) { _, shouldReduceMotion in
            spinnerIsAnimating = !shouldReduceMotion && visualState == .running
        }
        .onChange(of: jobPollingStore.completedRecordId) { _, recordId in
            consumeCompletion(recordId)
        }
    }

    private func startPollingIfNeeded() {
        guard !cancelled, !hasConsumed(jobId: jobId) else { return }

        if jobPollingStore.currentJob?.id == jobId,
           jobPollingStore.currentJob?.status == .succeeded {
            consumeCompletion(jobPollingStore.completedRecordId)
            return
        }

        jobPollingStore.startPolling(
            jobId: jobId,
            mode: mode,
            requestText: requestText,
            attachment: attachment,
            sourceChatRecordId: sourceChatRecordId
        )
    }

    private func consumeCompletion(_ recordId: UUID?) {
        guard !hasConsumed(jobId: jobId),
              let recordId,
              jobPollingStore.currentJob?.id == jobId,
              jobPollingStore.completedMode == mode else {
            return
        }

        markConsumed(jobId: jobId)
        jobPollingStore.stopPolling()

        switch mode {
        case .review:
            appState.path.append(.reviewResult(recordId: recordId))
        case .generate:
            appState.path.append(.generateResult(recordId: recordId))
        }
    }

    private func hasConsumed(jobId: String) -> Bool {
        consumedJobIDs.split(separator: "\n").contains { String($0) == jobId }
    }

    private func markConsumed(jobId: String) {
        var jobIDs = consumedJobIDs.split(separator: "\n").map(String.init)
        guard !jobIDs.contains(jobId) else { return }
        jobIDs.append(jobId)
        consumedJobIDs = jobIDs.suffix(32).joined(separator: "\n")
    }

    private var reviewProgressContent: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: proxy.size.height < 700 ? 16 : 22) {
                    ReviewProgressSpinner(
                        visualState: visualState,
                        isAnimating: spinnerIsAnimating && visualState == .running
                    )

                    VStack(spacing: 6) {
                        Text(titleText)
                            .font(QiheFont.title(size: 19))
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitleText)
                            .font(QiheFont.body(size: 13.5))
                            .foregroundStyle(QiheColor.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 300)

                    progressSteps

                    ContractProgressMeter(
                        progress: progressFraction,
                        visualState: visualState
                    )
                    .frame(maxWidth: 292)

                    if jobPollingStore.isPolling {
                        cancelButton
                    }

                    if let errorMessage = jobPollingStore.errorMessage {
                        errorState(message: errorMessage)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(proxy.size.height - 12, 0), alignment: .center)
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
        }
    }

    /// 生成模式继续使用改版前的进度结构与尺寸。
    private var generateProgressContent: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: compactSpacing(for: proxy.size.height)) {
                    ContractProgressSpinner(
                        visualState: visualState,
                        isAnimating: spinnerIsAnimating && visualState == .running
                    )

                    VStack(spacing: 6) {
                        Text(titleText)
                            .font(QiheFont.title(size: 20))
                            .foregroundStyle(titleColor)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitleText)
                            .font(QiheFont.body(size: 15))
                            .foregroundStyle(QiheColor.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: 292)

                    progressSteps

                    ContractProgressMeter(
                        progress: progressFraction,
                        visualState: visualState
                    )
                    .frame(maxWidth: 280)

                    if jobPollingStore.isPolling {
                        cancelButton
                    }

                    if let errorMessage = jobPollingStore.errorMessage {
                        errorState(message: errorMessage)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: max(proxy.size.height - 16, 0), alignment: .center)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
        }
    }

    private var progressBackground: some View {
        ZStack {
            QiheColor.neutral50.ignoresSafeArea()

            LinearGradient(
                colors: [
                    QiheColor.brandFrost.opacity(0.56),
                    QiheColor.neutral100.opacity(0.78),
                    QiheColor.neutral50
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.58)
                .ignoresSafeArea()
        }
    }

    private var visualState: ContractProgressVisualState {
        if jobPollingStore.errorMessage != nil || currentStatus == .failed {
            return .failed
        }
        if currentStatus == .succeeded {
            return .succeeded
        }
        return .running
    }

    private var currentStatus: JobStatus {
        jobPollingStore.currentJob?.status ?? .queued
    }

    private var titleText: String {
        switch visualState {
        case .running:
            return mode == .review ? "小契正在认真看合同" : "小契正在整理合同草案"
        case .succeeded:
            return mode == .review ? "审查完成" : "合同草案已生成"
        case .failed:
            return "处理失败"
        }
    }

    private var subtitleText: String {
        switch visualState {
        case .running:
            return mode == .review ? "我会先把需要注意的地方讲清楚" : "正在组织条款并标记待补充信息"
        case .succeeded:
            return "结果已准备好，即将打开"
        case .failed:
            return "请返回后重试，或稍后再试"
        }
    }

    private var titleColor: Color {
        switch visualState {
        case .running: return QiheColor.ink
        case .succeeded: return QiheColor.safeGreen
        case .failed: return QiheColor.riskRed
        }
    }

    private var stepTitles: [String] {
        mode == .review
            ? ["解析文件", "识别主体", "扫描风险条款", "生成审查报告"]
            : ["解析需求", "组织条款", "标记待补充", "生成合同草案"]
    }

    private var progressSteps: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(stepTitles.enumerated()), id: \.offset) { index, title in
                ContractProgressStepRow(
                    title: title,
                    state: stepState(at: index),
                    statusText: statusText(for: index),
                    isLast: index == stepTitles.count - 1
                )
            }
        }
        .frame(maxWidth: 292)
    }

    private var cancelButton: some View {
        Button {
            cancelAndGoBack()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 15, weight: .semibold))

                Text(mode == .review ? "取消分析" : "取消生成")
                    .font(QiheFont.body(size: 14, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(QiheColor.muted)
            .padding(.horizontal, 26)
            .padding(.vertical, 8)
            .frame(minHeight: actionMinHeight)
            .background(
                Capsule(style: .continuous)
                    .fill(QiheColor.neutral600.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(mode == .review ? "取消分析" : "取消生成")
    }

    private var progressFraction: Double {
        if visualState == .succeeded {
            return 1
        }

        if let progress = jobPollingStore.currentJob?.progress {
            let fraction = Double(progress) / 100
            return min(max(fraction, 0.08), visualState == .failed ? 1 : 0.96)
        }

        switch currentStatus {
        case .queued:
            return 0.16
        case .running:
            return [0.38, 0.56, 0.72, 0.88][activeStepIndex]
        case .succeeded:
            return 1
        case .failed:
            return max(0.18, [0.24, 0.42, 0.62, 0.78][activeStepIndex])
        }
    }

    private var activeStepIndex: Int {
        if currentStatus == .succeeded {
            return stepTitles.count - 1
        }

        if let progress = jobPollingStore.currentJob?.progress, progress > 0 {
            let clamped = min(max(progress, 0), 100)
            switch clamped {
            case 0..<28: return 0
            case 28..<52: return 1
            case 52..<78: return 2
            default: return 3
            }
        }

        if currentStatus == .running {
            return inferredActiveStepIndex
        }

        return 0
    }

    private var inferredActiveStepIndex: Int {
        let step = jobPollingStore.currentStep
        if mode == .review {
            if step.contains("报告") || step.contains("生成") { return 3 }
            if step.contains("风险") || step.contains("条款") || step.contains("扫描") { return 2 }
            if step.contains("主体") || step.contains("识别") || step.contains("分析") { return 1 }
            return 0
        }

        if step.contains("草案") || step.contains("生成") { return 3 }
        if step.contains("补充") || step.contains("标记") { return 2 }
        if step.contains("条款") || step.contains("起草") || step.contains("组织") { return 1 }
        return 0
    }

    private func stepState(at index: Int) -> ContractProgressStepState {
        if visualState == .succeeded {
            return .done
        }
        if visualState == .failed, index == activeStepIndex {
            return .failed
        }
        if index < activeStepIndex {
            return .done
        }
        if index == activeStepIndex {
            return .running
        }
        return .pending
    }

    private func statusText(for index: Int) -> String {
        switch stepState(at: index) {
        case .done:
            return "已完成"
        case .running:
            return "进行中"
        case .pending:
            return "等待中"
        case .failed:
            return "处理失败"
        }
    }

    private func compactSpacing(for height: CGFloat) -> CGFloat {
        height < 700 ? 18 : 24
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.top, 1)

                Text(message)
                    .font(QiheFont.body(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(QiheColor.riskRed)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: 292, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(QiheColor.riskRedSoft.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(QiheColor.riskRed.opacity(0.18), lineWidth: 1)
            )

            Button {
                goBack()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 14, weight: .semibold))

                    Text("返回")
                        .font(QiheFont.body(size: 14, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(QiheColor.riskRed)
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
                .frame(minHeight: actionMinHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(QiheColor.riskRedSoft)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func cancelAndGoBack() {
        cancelled = true
        jobPollingStore.cancelPolling()
        goBack()
    }

    private func goBack() {
        if !appState.path.isEmpty { appState.path.removeLast() }
    }
}

private enum ContractProgressVisualState: Equatable {
    case running
    case succeeded
    case failed
}

private enum ContractProgressStepState: Equatable {
    case done
    case running
    case pending
    case failed

    var iconBackground: Color {
        switch self {
        case .done:
            return QiheColor.safeGreenSoft
        case .running:
            return QiheColor.infoBlueSoft
        case .pending:
            return QiheColor.neutral600.opacity(0.10)
        case .failed:
            return QiheColor.riskRedSoft
        }
    }

    var iconForeground: Color {
        switch self {
        case .done:
            return QiheColor.safeGreen
        case .running:
            return QiheColor.brandBlue
        case .pending:
            return QiheColor.neutral300
        case .failed:
            return QiheColor.riskRed
        }
    }

    var titleColor: Color {
        switch self {
        case .done, .running:
            return QiheColor.ink
        case .pending:
            return QiheColor.neutral300
        case .failed:
            return QiheColor.riskRed
        }
    }

    var statusColor: Color {
        switch self {
        case .done:
            return QiheColor.safeGreen
        case .running:
            return QiheColor.brandBlue
        case .pending:
            return QiheColor.muted
        case .failed:
            return QiheColor.riskRed
        }
    }

    var symbolName: String {
        switch self {
        case .done:
            return "checkmark"
        case .running:
            return "arrow.triangle.2.circlepath"
        case .pending:
            return "circle"
        case .failed:
            return "xmark"
        }
    }
}

private struct ContractProgressSpinner: View {
    let visualState: ContractProgressVisualState
    let isAnimating: Bool

    var body: some View {
        ZStack {
            switch visualState {
            case .running:
                runningSpinner
            case .succeeded:
                terminalSpinner(color: QiheColor.safeGreen, systemImage: "checkmark")
            case .failed:
                terminalSpinner(color: QiheColor.riskRed, systemImage: "xmark")
            }
        }
        .frame(width: 136, height: 136)
        .accessibilityHidden(true)
    }

    private var runningSpinner: some View {
        ZStack {
            Circle()
                .fill(QiheColor.brandFrost.opacity(0.30))
                .frame(width: 120, height: 120)

            Circle()
                .stroke(QiheColor.brandBlue.opacity(0.14), lineWidth: 4)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: 0.64)
                .stroke(
                    AngularGradient(
                        colors: [QiheColor.brandBlue, QiheColor.brandLight, QiheColor.brandBlue.opacity(0.18)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(isAnimating ? 360 : -42))
                .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: isAnimating)

            spinnerCenter {
                QiheAssistantAvatar(size: 58)
            }
        }
    }

    private func terminalSpinner(color: Color, systemImage: String) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.10))
                .frame(width: 120, height: 120)

            Circle()
                .stroke(color.opacity(0.18), lineWidth: 7)
                .frame(width: 120, height: 120)

            Circle()
                .trim(from: 0, to: 0.82)
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-48))

            spinnerCenter {
                Image(systemName: systemImage)
                    .font(.system(size: 31, weight: .semibold))
                    .foregroundStyle(color)
            }
        }
    }

    private func spinnerCenter<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(QiheColor.neutral0.opacity(0.96))
            .frame(width: 84, height: 84)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(QiheColor.glassStroke, lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavy, radius: 16, x: 0, y: 5)
            .overlay(content())
    }
}

/// 参考稿的审查加载头图；只在 review 分支使用。
private struct ReviewProgressSpinner: View {
    let visualState: ContractProgressVisualState
    let isAnimating: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(centerBackground)
                .frame(width: 92, height: 92)

            Circle()
                .stroke(ringColor.opacity(0.14), lineWidth: 3)
                .frame(width: 92, height: 92)

            if visualState == .running {
                ReviewSpinnerArc(isAnimating: isAnimating)

                QiheAssistantAvatar(size: 60)
            } else {
                Circle()
                    .fill(ringColor.opacity(0.10))
                    .frame(width: 60, height: 60)

                Image(systemName: visualState == .succeeded ? "checkmark" : "xmark")
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: 104, height: 104)
        .accessibilityHidden(true)
    }

    private var ringColor: Color {
        switch visualState {
        case .running: return QiheColor.brandBlue
        case .succeeded: return QiheColor.safeGreen
        case .failed: return QiheColor.riskRed
        }
    }

    private var centerBackground: Color {
        switch visualState {
        case .running: return QiheColor.neutral0.opacity(0.96)
        case .succeeded: return QiheColor.safeGreenSoft
        case .failed: return QiheColor.riskRedSoft
        }
    }
}

private struct ReviewSpinnerArc: View {
    let isAnimating: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isAnimating)) { timeline in
            let phase = isAnimating
                ? timeline.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 1.1) / 1.1 * 360
                : 0

            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = max(0, min(size.width, size.height) / 2 - 2)
                var arc = Path()
                arc.addArc(
                    center: center,
                    radius: radius,
                    startAngle: .degrees(phase - 44),
                    endAngle: .degrees(phase + 179.2),
                    clockwise: false
                )
                context.stroke(
                    arc,
                    with: .color(QiheColor.brandBlue),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
            }
        }
        .frame(width: 92, height: 92)
        .accessibilityHidden(true)
    }
}

private struct ContractProgressStepRow: View {
    let title: String
    let state: ContractProgressStepState
    let statusText: String
    let isLast: Bool
    @ScaledMetric(relativeTo: .body) private var rowMinHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(state.iconBackground)

                    Image(systemName: state.symbolName)
                        .font(.system(size: state == .pending ? 15 : 18, weight: .semibold))
                        .foregroundStyle(state.iconForeground)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(QiheFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(state.titleColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(statusText)
                        .font(QiheFont.caption(size: 11, weight: .medium))
                        .foregroundStyle(state.statusColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .frame(minHeight: rowMinHeight)

            if !isLast {
                Rectangle()
                    .fill(connectorColor)
                    .frame(width: 2, height: 14)
                    .padding(.leading, 17)
            }
        }
    }

    private var connectorColor: Color {
        switch state {
        case .done:
            return QiheColor.safeGreen.opacity(0.30)
        case .failed:
            return QiheColor.riskRed.opacity(0.26)
        case .running, .pending:
            return QiheColor.neutral600.opacity(0.15)
        }
    }
}

private struct ContractProgressMeter: View {
    let progress: Double
    let visualState: ContractProgressVisualState

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("总进度")
                    .font(QiheFont.caption(size: 11, weight: .medium))
                    .foregroundStyle(QiheColor.muted)

                Spacer()

                Text("\(Int((progress * 100).rounded()))%")
                    .font(QiheFont.caption(size: 11, weight: .semibold))
                    .foregroundStyle(progressColor)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(QiheColor.brandBlue.opacity(0.12))

                    Capsule(style: .continuous)
                        .fill(progressFill)
                        .frame(width: max(5, proxy.size.width * CGFloat(progress)))
                }
            }
            .frame(height: 5)
        }
    }

    private var progressColor: Color {
        switch visualState {
        case .running:
            return QiheColor.brandBlue
        case .succeeded:
            return QiheColor.safeGreen
        case .failed:
            return QiheColor.riskRed
        }
    }

    private var progressFill: LinearGradient {
        switch visualState {
        case .running:
            return LinearGradient(
                colors: [QiheColor.brandLight, QiheColor.brandBlue],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .succeeded:
            return LinearGradient(
                colors: [QiheColor.safeGreen.opacity(0.78), QiheColor.safeGreen],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .failed:
            return LinearGradient(
                colors: [QiheColor.riskRed.opacity(0.72), QiheColor.riskRed],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
