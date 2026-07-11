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
    @State private var uploadCharacterCount: Int?
    @State private var pendingUploadFilename: String?
    @FocusState private var isPromptFocused: Bool

    /// 任务六：积分余额与不足引导
    @State private var creditBalance: CreditBalance?
    @State private var showInsufficientCreditsAlert = false
    @State private var insufficientAction: String = ""

    var body: some View {
        ZStack {
            HomeReferenceStyle.pageBackground
                .ignoresSafeArea()
                .onTapGesture {
                    isPromptFocused = false
                    QiheKeyboard.dismiss()
                }

            Circle()
                .fill(HomeReferenceStyle.topGlow)
                .frame(width: 260, height: 260)
                .offset(x: 154, y: -284)
                .allowsHitTesting(false)

            Circle()
                .fill(HomeReferenceStyle.sideGlow)
                .frame(width: 210, height: 210)
                .offset(x: -190, y: 82)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 16) {
                    brandTopBar
                    heroStatement
                    coreActions
                    chatEntry
                    uploadRecommendation
                    recentRecords
                    capabilityMatrix
                    healthLine
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, QiheLayout.rootTabBottomInset)
            }
            .qiheScrollDismissesKeyboard()
        }
        .qiheInlineNavigationTitle()
        .task {
            await checkHealth()
            await fetchCredits()
        }
        .refreshable {
            await checkHealth()
            await fetchCredits()
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: QiheDocumentValidator.allowedTypes
        ) { result in
            handleFileImport(result)
        }
        .alert("积分不足", isPresented: $showInsufficientCreditsAlert) {
            Button("去兑换") {
                appState.selectedTab = .profile
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("\(insufficientAction)需要消耗积分，当前积分不足。\n可前往「我的」页面兑换激活码或购买积分。")
        }
    }

    private var brandTopBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: 10) {
                QiheLogoMark(size: 36)

                Text("契合")
                    .font(QiheFont.h2(size: 21, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(HomeReferenceStyle.ink)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("契合")

            Spacer(minLength: 12)

            Button {
                isPromptFocused = false
                QiheKeyboard.dismiss()
                if !authStore.status.isSignedIn {
                    authStore.requestSignIn()
                }
                appState.selectedTab = .profile
            } label: {
                ZStack {
                    Circle()
                        .fill(QiheColor.glassFill)

                    if let avatarInitial {
                        Text(avatarInitial)
                            .font(QiheFont.body(size: 14, weight: .bold))
                            .foregroundStyle(QiheColor.brandBlue)
                            .lineLimit(1)
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(QiheColor.brandBlue)
                    }
                }
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.92), lineWidth: 1)
                )
                .shadow(color: HomeReferenceStyle.blue.opacity(0.14), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("打开个人中心")
        }
    }

    private var heroStatement: some View {
        HStack(alignment: .top, spacing: 4) {
            VStack(alignment: .leading, spacing: 0) {
                Label("专属法务助手", systemImage: "sparkles")
                    .font(QiheFont.body(size: 14, weight: .bold))
                    .foregroundStyle(HomeReferenceStyle.tealDeep)
                    .padding(.horizontal, 13)
                    .frame(height: 36)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0xDBF5F2), Color(hex: 0xE8F7EE)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.92), lineWidth: 1))
                    .shadow(color: HomeReferenceStyle.teal.opacity(0.12), radius: 8, x: 0, y: 4)

                Text("拟合同、审风险\n一句话就够了")
                    .font(QiheFont.display(size: 27, weight: .black))
                    .foregroundStyle(HomeReferenceStyle.ink)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.88)
                    .padding(.top, 14)

                Text("专业严谨、全程加密")
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(HomeReferenceStyle.muted)
                    .padding(.top, 10)
            }

            Spacer(minLength: 0)

            HomeAssistantMascot()
                .frame(width: 108, height: 154)
        }
        .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("专属法务助手小契。拟合同、审风险，一句话就够了。专业严谨、全程加密。")
    }

    private var coreActions: some View {
        HStack(spacing: 10) {
            HomeFeatureCard(
                title: "拟定合同",
                subtitle: "一句话生成合同",
                cost: "3 积分",
                systemImage: "doc.badge.plus",
                isPrimary: true
            ) {
                guard requireSignIn() else { return }
                guard requireCredits(3, action: "生成合同") else { return }
                isPromptFocused = false
                QiheKeyboard.dismiss()
                appState.path.append(.generate(prefill: nil))
            }

            HomeFeatureCard(
                title: "审查合同",
                subtitle: "上传文件标注风险",
                cost: "2 积分",
                systemImage: "checkmark.shield",
                isPrimary: false
            ) {
                guard requireSignIn() else { return }
                guard requireCredits(2, action: "审查合同") else { return }
                isPromptFocused = false
                QiheKeyboard.dismiss()
                appState.path.append(.review(prefill: nil))
            }
        }
    }

    private var chatEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("描述合同需求，或上传文件", text: $prompt, axis: .vertical)
                .font(QiheFont.body(size: 15))
                .foregroundStyle(HomeReferenceStyle.ink)
                .tint(HomeReferenceStyle.blue)
                .lineLimit(1...3)
                .frame(minHeight: 48, alignment: .topLeading)
                .focused($isPromptFocused)

            inputButtons
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.78))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.96), lineWidth: 1.5)
        )
        .shadow(color: HomeReferenceStyle.blue.opacity(0.15), radius: 18, x: 0, y: 10)
    }

    private var uploadFormatHint: some View {
        Text(isUploading ? "正在上传并解析文件…" : "PDF、DOCX、TXT · 最大 20MB")
            .font(QiheFont.caption(size: 12.5))
            .foregroundStyle(HomeReferenceStyle.subtle)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var inputButtons: some View {
        HStack(spacing: 9) {
            HomeInputIconButton(
                systemImage: "plus",
                accessibilityLabel: "上传文件",
                isLoading: isUploading,
                isDisabled: isUploading,
                isPrimary: false
            ) {
                guard requireSignIn() else {
                    return
                }
                isFileImporterPresented = true
            }

            uploadFormatHint

            Spacer(minLength: 0)

            HomeInputIconButton(
                systemImage: "arrow.up",
                accessibilityLabel: "发送",
                isDisabled: !canSendPrompt,
                isPrimary: true
            ) {
                sendPrompt()
            }
        }
    }

    private var capabilityMatrix: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionTitle(title: "契合能帮你做什么")

            LazyVGrid(columns: capabilityColumns, spacing: 0) {
                HomeCapabilityCell(
                    title: "智能起草",
                    detail: "生成条款完整的合同",
                    systemImage: "pencil.and.scribble",
                    tint: HomeReferenceStyle.blue
                )
                HomeCapabilityCell(
                    title: "风险审查",
                    detail: "逐条标注不利条款",
                    systemImage: "checkmark.shield",
                    tint: HomeReferenceStyle.teal
                )
                HomeCapabilityCell(
                    title: "条款解读",
                    detail: "大白话解释术语",
                    systemImage: "bubble.left",
                    tint: Color(hex: 0x6366F1)
                )
                HomeCapabilityCell(
                    title: "合规校验",
                    detail: "对照法规查漏补缺",
                    systemImage: "checkmark.circle",
                    tint: Color(hex: 0x16A34A)
                )
            }
            .background(Color.white.opacity(0.52))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.88), lineWidth: 1)
            )
            .shadow(color: HomeReferenceStyle.blue.opacity(0.06), radius: 12, x: 0, y: 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var capabilityColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 0),
            GridItem(.flexible(), spacing: 0)
        ]
    }

    private var avatarInitial: String? {
        guard case let .signedIn(user) = authStore.status else {
            return nil
        }
        let seed = user.displayName.nilIfBlank ?? user.account.nilIfBlank ?? "我"
        return String(seed.prefix(1)).uppercased()
    }

    @ViewBuilder
    private var uploadRecommendation: some View {
        VStack(spacing: 8) {
            if isUploading {
                QiheGlassCard(padding: 12, cornerRadius: QiheRadius.card) {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(QiheColor.brandBlue)
                            .frame(width: 34, height: 34)
                            .background(QiheColor.infoBlueSoft)
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(pendingUploadFilename ?? "合同文件")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(QiheColor.ink)
                                .lineLimit(1)

                            Text("正在上传并解析文件…")
                                .font(.caption)
                                .foregroundStyle(QiheColor.muted)
                        }

                        Spacer(minLength: 8)

                        QiheStatusPill(
                            text: "上传中",
                            color: QiheColor.brandBlue,
                            background: QiheColor.infoBlueSoft
                        )
                    }
                }
            }

            if let uploadError {
                ErrorBanner(message: uploadError, retryTitle: nil, retry: nil)
            }

            if let uploadedFile {
                QiheGlassCard(padding: 12, cornerRadius: QiheRadius.card) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(QiheColor.safeGreen)
                            .frame(width: 34, height: 34)
                            .background(QiheColor.safeGreenSoft)
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))

                        VStack(alignment: .leading, spacing: 3) {
                            Text(uploadedFile.filename)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(QiheColor.ink)
                                .lineLimit(1)

                            Text(uploadedFileDetail)
                                .font(.caption)
                                .foregroundStyle(QiheColor.muted)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 32)
                        .background {
                            RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                                .fill(QiheColor.primaryGradient)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous))
                    }
                }
            }
        }
    }

    private var uploadedFileDetail: String {
        if let uploadCharacterCount {
            return "\(uploadCharacterCount.formatted()) 字符 · 将按文件全文审查"
        }
        return "已上传 · 将按文件全文审查"
    }

    private var recentRecords: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                HomeSectionTitle(title: "最近记录")

                Spacer()

                Button {
                    isPromptFocused = false
                    QiheKeyboard.dismiss()
                    appState.selectedTab = .history
                } label: {
                    HStack(spacing: 3) {
                        Text(historyStore.records.isEmpty ? "暂无记录" : "共 " + String(historyStore.records.count) + " 份")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                }
                .font(QiheFont.caption(size: 13, weight: .medium))
                .foregroundStyle(historyStore.records.isEmpty ? HomeReferenceStyle.subtle : HomeReferenceStyle.blue)
                .disabled(historyStore.records.isEmpty)
            }

            if historyStore.records.isEmpty {
                QiheGlassCard(padding: 14, cornerRadius: QiheRadius.card) {
                    EmptyStateView(
                        title: "暂无最近记录",
                        detail: "从对话、审查或生成开始后，本地历史会出现在这里。"
                    )
                    .padding(.vertical, 2)
                }
            } else {
                VStack(spacing: 8) {
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
                .frame(width: 6, height: 6)

            Text(healthState.compactDetail(baseURL: appState.apiClient.baseURL))
                .font(QiheFont.caption(size: 10.5))
                .foregroundStyle(QiheColor.neutral600.opacity(0.68))
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
            .foregroundStyle(QiheColor.brandBlue.opacity(0.72))
            .disabled(healthState == .checking)
        }
        .padding(.horizontal, 2)
        .padding(.top, -4)
        .opacity(0.82)
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
            uploadedFile = file
            uploadCharacterCount = characterCount
            QiheUploadPresentationCache.store(characterCount: characterCount, for: file)
        } catch {
            characterCountTask.cancel()
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

    // MARK: - 积分（任务六）

    private func fetchCredits() async {
        guard authStore.status.isSignedIn else { return }
        do {
            creditBalance = try await appState.apiClient.getBalance()
        } catch {
            // 静默失败，不阻塞主流程
        }
    }

    /// 检查积分是否足够，不足时弹 alert 并返回 false
    private func requireCredits(_ needed: Int, action: String) -> Bool {
        guard let balance = creditBalance else {
            // 尚未加载余额，放行（后端会在请求时返回 402）
            return true
        }
        guard balance.credits >= needed else {
            insufficientAction = action
            showInsufficientCreditsAlert = true
            return false
        }
        return true
    }
}

private enum HomeReferenceStyle {
    static let blue = Color(hex: 0x2563EB)
    static let teal = Color(hex: 0x0891B2)
    static let tealDeep = Color(hex: 0x0E7490)
    static let ink = Color(hex: 0x14203A)
    static let muted = Color(hex: 0x64748B)
    static let subtle = Color(hex: 0x94A3B8)

    static let pageBackground = LinearGradient(
        colors: [Color(hex: 0xDFEAFF), Color(hex: 0xF5F9FF)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let topGlow = RadialGradient(
        colors: [Color.white.opacity(0.92), Color(hex: 0x93C5FD).opacity(0.48), .clear],
        center: .topLeading,
        startRadius: 0,
        endRadius: 132
    )

    static let sideGlow = RadialGradient(
        colors: [Color(hex: 0x60A5FA).opacity(0.18), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 105
    )
}

private struct HomeSectionTitle: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x3B82F6), Color(hex: 0x38BDF8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 3, height: 15)

            Text(title)
                .font(QiheFont.body(size: 15, weight: .bold))
                .foregroundStyle(HomeReferenceStyle.ink)
                .lineLimit(1)
        }
    }
}

private struct HomeInputIconButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var isLoading = false
    var isDisabled = false
    var isPrimary = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(isPrimary ? .white : HomeReferenceStyle.blue)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                }
            }
            .frame(width: 40, height: 40)
            .foregroundStyle(isPrimary ? Color.white : HomeReferenceStyle.blue)
            .background {
                if isPrimary {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x3B82F6), HomeReferenceStyle.blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.86))
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: isPrimary ? 13 : 12, style: .continuous)
                    .stroke(isPrimary ? .clear : HomeReferenceStyle.blue.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: isPrimary ? HomeReferenceStyle.blue.opacity(0.30) : .clear, radius: 7, x: 0, y: 4)
            .opacity(isDisabled ? 0.48 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// 正式角色素材交付前的 SwiftUI 占位，不截取参考稿位图。
private struct HomeAssistantMascot: View {
    var body: some View {
        ZStack(alignment: .top) {
            Ellipse()
                .fill(HomeReferenceStyle.blue.opacity(0.15))
                .frame(width: 62, height: 10)
                .blur(radius: 3)
                .offset(y: 140)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xCFE1FF), Color(hex: 0x6EA3F5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 9, height: 23)
                .rotationEffect(.degrees(20))
                .offset(x: -48, y: 91)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xCFE1FF), Color(hex: 0x6EA3F5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 9, height: 23)
                .rotationEffect(.degrees(-20))
                .offset(x: 48, y: 91)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .white,
                                Color(hex: 0xD3E7FF),
                                Color(hex: 0x8FBCFF),
                                Color(hex: 0x4A86EE),
                                Color(hex: 0x2F63D4)
                            ],
                            center: UnitPoint(x: 0.31, y: 0.23),
                            startRadius: 0,
                            endRadius: 72
                        )
                    )
                    .shadow(color: Color(hex: 0x2B62D4).opacity(0.34), radius: 17, x: 0, y: 12)

                Ellipse()
                    .fill(Color.white.opacity(0.58))
                    .frame(width: 32, height: 16)
                    .blur(radius: 4)
                    .offset(x: -18, y: -27)

                HStack(spacing: 16) {
                    mascotEye
                    mascotEye
                }
                .offset(y: -5)

                HStack(spacing: 37) {
                    Ellipse()
                        .fill(Color(hex: 0xFF7890).opacity(0.42))
                        .frame(width: 11, height: 6)
                    Ellipse()
                        .fill(Color(hex: 0xFF7890).opacity(0.42))
                        .frame(width: 11, height: 6)
                }
                .blur(radius: 0.8)
                .offset(y: 14)

                Path { path in
                    path.move(to: CGPoint(x: 1, y: 1))
                    path.addQuadCurve(
                        to: CGPoint(x: 21, y: 1),
                        control: CGPoint(x: 11, y: 13)
                    )
                }
                .stroke(Color(hex: 0x17264A), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .frame(width: 22, height: 12)
                .offset(y: 18)
            }
            .frame(width: 96, height: 96)
            .offset(y: 42)

            Image(systemName: "sparkle")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color(hex: 0x7FB0FF))
                .shadow(color: HomeReferenceStyle.blue.opacity(0.38), radius: 4)
                .offset(x: 37, y: 33)

            Text("你好，我是小契~")
                .font(QiheFont.caption(size: 12.5, weight: .semibold))
                .foregroundStyle(Color(hex: 0x1E40AF))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 10)
                .frame(height: 31)
                .background(Color.white)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 3,
                        bottomTrailingRadius: 12,
                        topTrailingRadius: 12,
                        style: .continuous
                    )
                )
                .shadow(color: HomeReferenceStyle.blue.opacity(0.20), radius: 8, x: 0, y: 4)
                .offset(x: -16, y: 0)
        }
        .accessibilityHidden(true)
    }

    private var mascotEye: some View {
        ZStack(alignment: .topLeading) {
            Ellipse()
                .fill(Color.white)
                .frame(width: 15, height: 18)

            Ellipse()
                .fill(Color(hex: 0x17264A))
                .frame(width: 8, height: 10)
                .offset(x: 4, y: 4)

            Circle()
                .fill(Color.white)
                .frame(width: 3, height: 3)
                .offset(x: 6, y: 5)
        }
        .frame(width: 15, height: 18)
    }
}

private struct HomeFeatureCard: View {
    let title: String
    let subtitle: String
    let cost: String
    let systemImage: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: isPrimary ? "doc.text" : "checkmark.shield")
                    .font(.system(size: 82, weight: .ultraLight))
                    .foregroundStyle(accent.opacity(0.09))
                    .offset(x: 20, y: 18)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        Image(systemName: systemImage)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 50, height: 50)
                            .background(iconGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: accent.opacity(0.36), radius: 10, x: 0, y: 6)

                        Spacer(minLength: 6)

                        Text(cost)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 7)
                            .frame(height: 22)
                            .background(Color.white.opacity(0.58))
                            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))
                    }

                    Spacer(minLength: 14)

                    Text(title)
                        .font(QiheFont.body(size: 17, weight: .bold))
                        .foregroundStyle(HomeReferenceStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(subtitle)
                        .font(QiheFont.body(size: 13.5))
                        .foregroundStyle(HomeReferenceStyle.muted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 3) {
                        Text(isPrimary ? "开始拟定" : "开始审查")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(QiheFont.body(size: 13.5, weight: .semibold))
                    .foregroundStyle(accent)
                    .padding(.top, 8)
                }
                .padding(18)
                .frame(maxWidth: .infinity, minHeight: 166, alignment: .leading)
            }
            .background(cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.95), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.15), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(.plain)
    }

    private var accent: Color {
        isPrimary ? HomeReferenceStyle.blue : HomeReferenceStyle.teal
    }

    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: isPrimary
                ? [Color(hex: 0x4C93FF), HomeReferenceStyle.blue]
                : [Color(hex: 0x22C3D6), HomeReferenceStyle.teal],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: isPrimary
                ? [Color(hex: 0xD9E8FF), Color(hex: 0xF3F7FF)]
                : [Color(hex: 0xCCF1F7), Color(hex: 0xF0FDFF)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct HomeCapabilityCell: View {
    let title: String
    let detail: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(QiheFont.body(size: 13, weight: .bold))
                    .foregroundStyle(HomeReferenceStyle.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(detail)
                    .font(QiheFont.caption(size: 10.5))
                    .foregroundStyle(HomeReferenceStyle.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(HomeReferenceStyle.blue.opacity(0.05), lineWidth: 0.5)
        )
    }
}

private struct HomeRecentRecordRow: View {
    let record: HistoryRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 44, height: 44)
                    .background(iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(record.title.nilIfBlank ?? "未命名记录")
                        .font(QiheFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(HomeReferenceStyle.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)

                    Text(Self.dateFormatter.string(from: record.updatedAt))
                        .font(QiheFont.caption(size: 11))
                        .foregroundStyle(HomeReferenceStyle.subtle)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                QiheRiskBadge(level: badgeLevel, text: badgeText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.78))
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                    .stroke(Color.white.opacity(0.92), lineWidth: 1)
            )
            .shadow(color: HomeReferenceStyle.blue.opacity(0.07), radius: 12, x: 0, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
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

    private var badgeText: String {
        switch record.type {
        case .chat:
            return "对话"
        case .review:
            return "审查"
        case .generate:
            return "拟定"
        }
    }

    private var badgeLevel: RiskLevel {
        switch record.type {
        case .chat:
            return .unknown
        case .review:
            return .medium
        case .generate:
            return .unknown
        }
    }

    private var iconColor: Color {
        switch record.type {
        case .chat:
            return QiheColor.brandNavy
        case .review:
            return QiheColor.riskOrange
        case .generate:
            return QiheColor.brandBlue
        }
    }

    private var iconBackground: Color {
        switch record.type {
        case .chat:
            return QiheColor.brandFrost.opacity(0.34)
        case .review:
            return QiheColor.riskOrangeSoft
        case .generate:
            return QiheColor.infoBlueSoft
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
            return QiheColor.riskOrange
        case .online:
            return QiheColor.safeGreen
        case .offline:
            return QiheColor.riskRed
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
