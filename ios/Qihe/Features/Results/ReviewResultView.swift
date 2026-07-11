import Foundation
import SwiftUI

struct ReviewResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var revisionStore: RevisionStore
    let recordId: UUID
    @State private var selectedTab: ReviewResultTab = .risks
    @State private var isExporting = false
    @State private var shareDocument: ShareDocument?
    @State private var errorMessage: String?
    @State private var highlightedRiskID: UUID?
    @State private var selectedRiskForDetail: RiskItem?
    @State private var selectedRiskForEdit: RiskItem?
    @State private var showLocateDialog = false
    @State private var locateTargetParagraphID: Int?
    @State private var flashParagraphID: Int?

    private var confirmedRiskIDs: Set<String> {
        revisionStore.confirmedRiskIDs(for: recordId)
    }

    private var resultNavigationTitle: String {
        guard let payload = historyStore.record(id: recordId)?.reviewPayload else {
            return "审查报告"
        }
        return payload.attachment?.filename.nilIfBlank
            ?? payload.result.title?.nilIfBlank
            ?? "审查报告"
    }

    var body: some View {
        ZStack {
            QiheColor.pageBackgroundGradient.ignoresSafeArea()

            if let payload = historyStore.record(id: recordId)?.reviewPayload {
                VStack(spacing: 0) {
                    tabBar

                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if let errorMessage {
                                    ErrorBanner(message: errorMessage, retryTitle: "重试导出") {
                                        Task {
                                            await exportWord(payload)
                                        }
                                    }
                                }

                                switch selectedTab {
                                case .source:
                                    sourceTab(payload)
                                case .risks:
                                    riskTab(payload.result)
                                case .subjects:
                                    subjectsTab(payload.result)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 10)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 40, coordinateSpace: .local)
                                .onEnded { value in
                                    let horizontalAmount = value.translation.width
                                    let verticalAmount = abs(value.translation.height)

                                    // 仅在水平滑动明显大于垂直滑动时触发
                                    guard abs(horizontalAmount) > verticalAmount * 1.2 else {
                                        return
                                    }

                                    if horizontalAmount > 0 && selectedTab == .source {
                                        // 右滑：从原文切到风险列表
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            selectedTab = .risks
                                        }
                                    } else if horizontalAmount < 0 && selectedTab == .risks {
                                        // 左滑：从风险列表切回原文
                                        withAnimation(.easeInOut(duration: 0.22)) {
                                            selectedTab = .source
                                        }
                                    }
                                }
                        )
                        .onChange(of: highlightedRiskID) { _, _ in
                            scrollToHighlightedRisk(in: proxy)
                        }
                        .onChange(of: selectedTab) { _, newTab in
                            guard newTab == .risks else {
                                return
                            }
                            scrollToHighlightedRisk(in: proxy)
                        }
                        .onChange(of: locateTargetParagraphID) { _, newID in
                            guard let id = newID else { return }
                            withAnimation(.easeInOut(duration: 0.26)) {
                                proxy.scrollTo(id, anchor: .top)
                            }
                            flashParagraphID = id
                            // 重置，确保再次选择同一风险时仍能触发滚动
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                locateTargetParagraphID = nil
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                                withAnimation(.easeOut(duration: 0.4)) {
                                    flashParagraphID = nil
                                }
                            }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    title: "无法读取审查结果",
                    detail: "这条历史可能已经被清空。"
                )
                .padding(24)
            }
        }
        .navigationTitle(resultNavigationTitle)
        .qiheInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .qiheTopTrailing) {
                Button {
                    if let payload = historyStore.record(id: recordId)?.reviewPayload {
                        Task {
                            await exportWord(payload)
                        }
                    }
                } label: {
                    Image(systemName: isExporting ? "hourglass" : "square.and.arrow.up")
                }
                .foregroundStyle(QiheColor.navy)
                .disabled(historyStore.record(id: recordId)?.reviewPayload == nil || isExporting)
                .accessibilityLabel("导出 Word")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let payload = historyStore.record(id: recordId)?.reviewPayload {
                reviewActionBar(payload)
            }
        }
        .sheet(item: $shareDocument) { document in
            ShareSheet(document: document)
        }
        .sheet(item: $selectedRiskForDetail) { risk in
            RiskDetailSheet(
                risk: risk,
                paragraphText: resolvedParagraphText(for: risk),
                isConfirmed: confirmedRiskIDs.contains(risk.id.uuidString),
                onDismiss: { selectedRiskForDetail = nil },
                onConfirm: { beforeText, afterText in
                    revisionStore.saveRevision(
                        recordId: recordId,
                        riskId: risk.id.uuidString,
                        beforeText: beforeText,
                        afterText: afterText,
                        syncToBackend: true
                    )
                    selectedRiskForDetail = nil
                },
                onEdit: {
                    selectedRiskForDetail = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        selectedRiskForEdit = risk
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedRiskForEdit) { risk in
            RiskEditSheet(
                risk: risk,
                paragraphText: resolvedParagraphText(for: risk),
                onDismiss: { selectedRiskForEdit = nil },
                onConfirm: { beforeText, afterText in
                    revisionStore.saveRevision(
                        recordId: recordId,
                        riskId: risk.id.uuidString,
                        beforeText: beforeText,
                        afterText: afterText,
                        syncToBackend: true
                    )
                    selectedRiskForEdit = nil
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog("定位风险", isPresented: $showLocateDialog, titleVisibility: .visible) {
            if let risks = historyStore.record(id: recordId)?.reviewPayload?.result.risks,
               !risks.isEmpty {
                ForEach(risks) { risk in
                    Button {
                        locateRisk(risk)
                    } label: {
                        HStack {
                            Circle()
                                .fill(sourceRiskColor(for: risk.riskLevel))
                                .frame(width: 8, height: 8)
                            Text(risk.displayTitle)
                                .lineLimit(1)
                        }
                    }
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("选择一个风险项，自动跳转到原文对应段落并高亮")
        }
        .task {
            // 任务三：视图出现时从后端拉取 revisions 并合并到本地缓存
            _ = await revisionStore.fetchAndMergeRevisions(recordId: recordId)
        }
    }

    private func resolvedParagraphText(for risk: RiskItem) -> String {
        guard let payload = historyStore.record(id: recordId)?.reviewPayload else {
            return risk.originalExcerpt ?? risk.originalText ?? ""
        }
        let sourceMap = buildSourceMap(from: payload)
        if let paragraph = sourceMap.paragraphs.first(where: { $0.risks.contains(where: { $0.id == risk.id }) }) {
            return paragraph.text
        }
        return risk.originalExcerpt ?? risk.originalText ?? ""
    }

    /// 定位风险：切换到原文 tab 并滚动到该风险所在的段落
    private func locateRisk(_ risk: RiskItem) {
        guard let payload = historyStore.record(id: recordId)?.reviewPayload else { return }
        let sourceMap = buildSourceMap(from: payload)

        guard let paragraph = sourceMap.paragraphs.first(where: { $0.risks.contains(where: { $0.id == risk.id }) }) else {
            // 如果在原文中无法定位，回退到风险列表 tab
            highlightedRiskID = risk.id
            selectedTab = .risks
            return
        }

        // 切换到原文 tab 并触发滚动+高亮
        selectedTab = .source
        locateTargetParagraphID = paragraph.id
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ReviewResultTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(QiheFont.body(size: 14, weight: selectedTab == tab ? .semibold : .medium))
                        .foregroundStyle(selectedTab == tab ? QiheColor.brandBlue : QiheColor.neutral300)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(QiheColor.brandBlue)
                                    .frame(height: 2.5)
                                    .padding(.horizontal, 10)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .background {
            Rectangle()
                .fill(QiheColor.glassFill.opacity(0.86))
                .background(.ultraThinMaterial)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(QiheColor.glassStroke.opacity(0.72))
                .frame(height: 1)
        }
    }

    private func sourceTab(_ payload: ReviewHistoryPayload) -> some View {
        let sourceMap = buildSourceMap(from: payload)

        return OriginalRiskDocumentView(
            sourceMap: sourceMap,
            documentTitle: payload.attachment?.filename ?? payload.result.displayTitle,
            attachmentFilename: payload.attachment?.filename,
            displayedRiskCount: payload.result.displayedRiskCount,
            confirmedRiskIDs: confirmedRiskIDs,
            flashParagraphID: flashParagraphID,
            onSelectRisk: { risk in
                selectedRiskForDetail = risk
            },
            onFocusUnlocatedRisk: { risk in
                selectedRiskForDetail = risk
            }
        )
    }

    private var noObviousRiskBanner: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [QiheColor.safeGreenSoft, QiheColor.neutral0],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(QiheColor.safeGreen)
            }
            .frame(width: 64, height: 64)
            .shadow(color: QiheColor.safeGreen.opacity(0.14), radius: 14, x: 0, y: 7)
            .accessibilityHidden(true)

            Text("未发现明显风险")
                .font(QiheFont.title(size: 17))
                .foregroundStyle(QiheColor.ink)
                .padding(.top, 16)

            Text("已逐条检查合同内容，未发现明显不利或缺失条款。签署前仍建议核对主体、金额与期限。")
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.muted)
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
                .frame(maxWidth: 276)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 42)
        .padding(.bottom, 70)
        .accessibilityElement(children: .combine)
    }

    /// 构建 SourceRiskMap：优先后端 blocks，回退前端分段
    private func buildSourceMap(from payload: ReviewHistoryPayload) -> SourceRiskMap {
        // 任务三：优先后端 blocks
        if let blocks = payload.result.blocks, !blocks.isEmpty {
            return SourceRiskLocator.annotate(
                blocks: blocks,
                risks: payload.result.risks
            )
        }
        // 回退：前端本地分段
        let resolvedText = resolveSourceText(from: payload)
        return SourceRiskLocator.annotate(result: payload.result, sourceTextOverride: resolvedText)
    }

    /// 按优先级解析合同原文来源
    ///
    /// 优先级：
    /// 1. result.source.originalText（后端完整原文）
    /// 2. payload.requestText（用户提交审查时的文本）
    /// 3. result.source.textPreview（后端文本预览，通常截断到240字）
    /// 4. risk.originalExcerpt 拼接（从各风险项原文摘录拼凑）
    /// 5. result.summary（仅使用结果摘要）
    private func resolveSourceText(from payload: ReviewHistoryPayload) -> String {
        if let text = payload.result.source?.originalText?.nilIfBlank {
            return text
        }
        if let text = payload.requestText.nilIfBlank {
            return text
        }
        if let text = payload.result.source?.textPreview?.nilIfBlank {
            return text
        }
        let excerpts = payload.result.risks.compactMap { $0.originalExcerpt?.nilIfBlank }
        if !excerpts.isEmpty {
            return excerpts.joined(separator: "\n")
        }
        return payload.result.summary?.nilIfBlank ?? "暂无原文。"
    }

    private func riskTab(_ result: ReviewResult) -> some View {
        Group {
            if result.risks.isEmpty {
                noObviousRiskBanner
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    reportHead(result)
                    statStrip(result)

                ForEach(result.risks) { risk in
                        RiskReportCard(
                            risk: risk,
                            isHighlighted: highlightedRiskID == risk.id,
                            onShowSuggestion: {
                                selectedRiskForDetail = risk
                            }
                        )
                            .id(risk.id)
                    }
                }
            }
        }
    }

    private func focusRisk(_ risk: RiskItem) {
        highlightedRiskID = risk.id
        selectedTab = .risks
    }

    private func scrollToHighlightedRisk(in proxy: ScrollViewProxy) {
        guard selectedTab == .risks, let highlightedRiskID else {
            return
        }

        withAnimation(.easeInOut(duration: 0.26)) {
            proxy.scrollTo(highlightedRiskID, anchor: .top)
        }
    }

    private func reportHead(_ result: ReviewResult) -> some View {
        QiheGlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(result.displayTitle)
                            .font(QiheFont.title(size: 20))
                            .foregroundStyle(QiheColor.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(
                            result.risks.isEmpty
                                ? "审查报告已生成，原文、主体信息与审查依据均已保留。"
                                : "审查报告已生成，请重点查看风险条款与修改建议。"
                        )
                            .font(QiheFont.caption(size: 12))
                            .foregroundStyle(QiheColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    if result.risks.isEmpty {
                        QiheStatusPill(
                            text: "无明显风险",
                            color: QiheColor.safeGreen,
                            background: QiheColor.safeGreenSoft
                        )
                    } else {
                        QiheRiskBadge(level: result.riskLevel ?? .pending)
                    }
                }

                Text(
                    result.summary?.nilIfBlank
                        ?? (result.risks.isEmpty
                            ? "未识别到明确风险项，请继续核对合同关键事实。"
                            : "审查报告已生成，请重点查看风险卡片。")
                )
                    .font(QiheFont.body(size: 13))
                    .foregroundStyle(QiheColor.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.top, 1)

                    Text("审查依据：\(result.reviewBasis?.nilIfBlank ?? "中国大陆现行法律")")
                        .font(QiheFont.caption(size: 11.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(QiheColor.brandBlue)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(QiheColor.infoBlueSoft.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
            }
        }
    }

    private func statStrip(_ result: ReviewResult) -> some View {
        HStack(spacing: 0) {
            ReviewStatCell(value: "\(result.displayedRiskCount)", label: "风险数量")
            ReviewStatCell(value: "\(result.score ?? scoreFallback(for: result.riskLevel))", label: "综合评分")
            ReviewStatCell(value: gradeLetter(for: result.riskLevel), label: "风险等级", color: (result.riskLevel ?? .pending).foreground)
        }
        .background(QiheColor.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(QiheColor.glassStroke, lineWidth: 1)
        )
        .shadow(color: QiheColor.shadowNavySoft, radius: 8, x: 0, y: 2)
    }

    private func subjectsTab(_ result: ReviewResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            QiheSectionHeader(title: "主体信息", subtitle: "合同当事人与关键信息")

            SubjectFactsPanel(result: result)

            QiheSecondaryButton(title: "查看主体信息", systemImage: "person.text.rectangle") {
                appState.path.append(.subject(recordId: recordId))
            }
        }
    }

    private func reviewActionBar(_ payload: ReviewHistoryPayload) -> some View {
        HStack(spacing: 10) {
            ReviewActionIconButton(title: "定位", systemImage: "location.magnifyingglass") {
                showLocateDialog = true
            }

            ReviewActionIconButton(title: "修改", systemImage: "square.and.pencil") {
                guard requireSignIn() else {
                    return
                }
                appState.path.append(
                    .review(
                        prefill: reviewContinuationText(from: payload),
                        attachment: payload.attachment
                    )
                )
            }

            QihePrimaryButton(title: "追问 AI", systemImage: "sparkles") {
                guard requireSignIn() else {
                    return
                }
                appState.path.append(.chat(localRecordId: nil, initialMessage: followUpPrompt(for: payload)))
            }
            .frame(minWidth: 138)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .background {
            Rectangle()
                .fill(QiheColor.glassFill.opacity(0.92))
                .background(.ultraThinMaterial)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(QiheColor.glassStroke.opacity(0.76))
                .frame(height: 1)
        }
    }

    private func reviewContinuationText(from payload: ReviewHistoryPayload) -> String? {
        if payload.attachment != nil {
            return payload.requestText.nilIfBlank
        }

        return payload.result.source?.originalText?.nilIfBlank
            ?? payload.requestText.nilIfBlank
            ?? payload.result.source?.textPreview?.nilIfBlank
            ?? payload.result.summary?.nilIfBlank
    }

    private func followUpPrompt(for payload: ReviewHistoryPayload) -> String {
        let result = payload.result
        let summary = result.summary?.nilIfBlank ?? "暂无审查摘要。"
        let selectedRisk = selectedFollowUpRisk(in: result)
        let excerpt = followUpExcerpt(for: result, risk: selectedRisk)

        guard let risk = selectedRisk else {
            return [
                "请基于这份合同审查结果，继续帮我判断下一步怎么改。",
                "审查摘要：\(summary)",
                "原文摘录：\(excerpt)"
            ].joined(separator: "\n")
        }

        var lines = [
            "请基于这份合同审查结果，继续帮我判断下一步怎么改。",
            "审查摘要：\(summary)",
            "综合风险等级：\((result.riskLevel ?? risk.riskLevel).label)",
            "风险标题：\(risk.displayTitle)"
        ]

        if let clause = followUpClause(for: risk) {
            lines.append("涉及条款：\(clause)")
        }
        if let analysis = risk.displayAnalysis?.nilIfBlank {
            lines.append("风险分析：\(analysis.truncated(to: 160))")
        }
        if let suggestion = risk.displaySuggestion?.nilIfBlank {
            lines.append("修订建议：\(suggestion.truncated(to: 160))")
        }
        lines.append("原文摘录：\(excerpt)")
        return lines.joined(separator: "\n")
    }

    private func selectedFollowUpRisk(in result: ReviewResult) -> RiskItem? {
        if let highlightedRiskID,
           let highlightedRisk = result.risks.first(where: { $0.id == highlightedRiskID }) {
            return highlightedRisk
        }

        return result.risks.sortedForSourceDisplay.first
    }

    private func followUpClause(for risk: RiskItem) -> String? {
        risk.clause?.nilIfBlank
            ?? risk.clauseTitle?.nilIfBlank
            ?? risk.clauseId?.nilIfBlank
    }

    private func followUpExcerpt(for result: ReviewResult, risk: RiskItem?) -> String {
        let excerpt = risk?.originalExcerpt?.nilIfBlank
            ?? risk?.originalText?.nilIfBlank
            ?? result.source?.originalText?.nilIfBlank
            ?? result.source?.textPreview?.nilIfBlank
            ?? "暂无原文摘录。"
        return cappedText(excerpt, limit: 300)
    }

    private func cappedText(_ text: String, limit: Int) -> String {
        let cleaned = text.trimmedForInput
        guard cleaned.count > limit else {
            return cleaned
        }
        return String(cleaned.prefix(limit))
    }

    private func exportWord(_ payload: ReviewHistoryPayload) async {
        guard authStore.status.isSignedIn else {
            await MainActor.run {
                openSignIn()
            }
            return
        }
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            // 任务三：导出时使用修改后的 blocks
            var exportResult = payload.result
            if let blocks = payload.result.blocks, !blocks.isEmpty {
                let confirmedStates = revisionStore.confirmedBlockStates(for: recordId)
                let confirmedRevisions = revisionStore.revisions(for: recordId)
                    .filter { $0.status == .confirmed }
                exportResult.blocks = buildExportBlocks(
                    from: blocks,
                    confirmedStates: confirmedStates,
                    confirmedRevisions: confirmedRevisions
                )
            }
            let url = try await appState.apiClient.exportReviewWord(
                title: payload.result.displayTitle,
                payload: exportResult
            )
            shareDocument = ShareDocument(url: url)
        } catch {
            errorMessage = error.qiheDisplayMessage
        }
    }

    /// 构建导出用的 blocks，替换已确认修改的文本（任务三）
    private func buildExportBlocks(
        from blocks: [ContractBlock],
        confirmedStates: [String: RevisionState],
        confirmedRevisions: [LocalRevision]
    ) -> [ContractBlock] {
        // 构建 riskId → afterText 的快速查找
        var revisionTextByRiskID: [String: String] = [:]
        for rev in confirmedRevisions {
            if let riskId = rev.riskId {
                revisionTextByRiskID[riskId] = rev.afterText
            }
        }

        return blocks.map { block in
            var modifiedBlock = block
            // 如果有风险已修改，更新 block 文本
            if let riskIds = block.riskIds {
                for riskId in riskIds {
                    if let newText = revisionTextByRiskID[riskId] {
                        modifiedBlock.text = newText
                        break
                    }
                }
            }
            // 如果 block 本身状态为 confirmed，也标记
            if confirmedStates[block.id] == .confirmed {
                // block 文本可能已在块级别被修改
            }
            return modifiedBlock
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

    private func gradeLetter(for level: RiskLevel?) -> String {
        switch level ?? .pending {
        case .high:
            return "D"
        case .medium:
            return "C"
        case .low:
            return "A"
        case .pending, .unknown:
            return "-"
        }
    }

    private func scoreFallback(for level: RiskLevel?) -> Int {
        switch level ?? .pending {
        case .high:
            return 55
        case .medium:
            return 76
        case .low:
            return 92
        case .pending, .unknown:
            return 0
        }
    }
}

private enum ReviewResultTab: CaseIterable {
    case source
    case risks
    case subjects

    var title: String {
        switch self {
        case .source:
            return "原文"
        case .risks:
            return "风险"
        case .subjects:
            return "主体信息"
        }
    }
}

private struct ReviewRiskGradeStamp: View {
    let level: RiskLevel

    var body: some View {
        VStack(spacing: 3) {
            Text(letter)
                .font(QiheFont.title(size: 22))
            Text(level.label)
                .font(QiheFont.caption(size: 8.5, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(level.foreground)
        .frame(width: 58, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(level.foreground, lineWidth: 2.5)
        )
        .background(QiheColor.card.opacity(0.6))
        .rotationEffect(.degrees(7))
    }

    private var letter: String {
        switch level {
        case .high:
            return "D"
        case .medium:
            return "C"
        case .low:
            return "A"
        case .pending, .unknown:
            return "-"
        }
    }
}

private struct ReviewStatCell: View {
    let value: String
    let label: String
    var color: Color = QiheColor.ink

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(QiheFont.title(size: 22))
                .foregroundStyle(color)
            Text(label)
                .font(QiheFont.caption(size: 10.5))
                .foregroundStyle(QiheColor.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(QiheColor.lineStrong)
                .frame(width: 1)
                .opacity(label == "风险等级" ? 0 : 0.7)
        }
    }
}

private struct ReviewActionIconButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(height: 20)

                Text(title)
                    .font(QiheFont.micro(size: 9.5, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(QiheColor.brandBlue)
            .frame(width: 48, height: 48)
            .background(QiheColor.infoBlueSoft)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

struct SourceRiskMap {
    let paragraphs: [AnnotatedSourceParagraph]
    let unmatchedRisks: [RiskItem]
}

private struct SourceTextParagraph {
    let id: Int
    let text: String
    let normalizedText: String
    let startOffset: Int?
    let endOffset: Int?

    init(id: Int, text: String, startOffset: Int? = nil, endOffset: Int? = nil) {
        self.id = id
        self.text = text
        self.startOffset = startOffset
        self.endOffset = endOffset
        normalizedText = text.sourceMatchNormalized
    }
}

struct AnnotatedSourceParagraph: Identifiable {
    let id: Int
    let text: String
    let risks: [RiskItem]

    var primaryRisk: RiskItem? {
        risks.first
    }
}

struct UnlocatedRiskNotice: View {
    let risks: [RiskItem]
    let onSelectRisk: (RiskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14, weight: .semibold))

                Text("未能精确定位的风险")
                    .font(QiheFont.body(size: 13, weight: .semibold))

                Spacer()

                Text("\(risks.count)项")
                    .font(QiheFont.caption(size: 11, weight: .semibold))
                    .padding(.horizontal, 7)
                    .frame(height: 23)
                    .foregroundStyle(QiheColor.amber)
                    .background(QiheColor.card.opacity(0.78))
                    .clipShape(Capsule())
            }
            .foregroundStyle(QiheColor.amber)

            FlowLayout(spacing: 6) {
                ForEach(Array(risks.prefix(4))) { risk in
                    Button {
                        onSelectRisk(risk)
                    } label: {
                        Text(risk.displayTitle.truncated(to: 16))
                            .font(QiheFont.caption(size: 11, weight: .semibold))
                            .foregroundStyle(QiheColor.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 8)
                            .frame(height: 26)
                            .background(QiheColor.card.opacity(0.76))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if risks.count > 4 {
                    Text("+\(risks.count - 4)")
                        .font(QiheFont.caption(size: 11, weight: .semibold))
                        .foregroundStyle(QiheColor.muted)
                        .padding(.horizontal, 8)
                        .frame(height: 26)
                        .background(QiheColor.card.opacity(0.76))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.amberSoft.opacity(0.76))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(QiheColor.amber.opacity(0.28), lineWidth: 1)
        )
    }
}

// MARK: - 原文风险文档视图

/// 原文风险文档视图：以段落形式展示合同原文，并为有风险的段落标记彩色风险色块。
///
/// 颜色规则：
/// - 高风险 → 红色（seal）
/// - 中风险 → 橙色（amber）
/// - 低风险/已修改 → 绿色（pine）
/// - 待确认/未评级 → 信息蓝（navy）
struct OriginalRiskDocumentView: View {
    let sourceMap: SourceRiskMap
    var documentTitle: String
    var attachmentFilename: String?
    var displayedRiskCount: Int
    var confirmedRiskIDs: Set<String> = []
    var flashParagraphID: Int?
    var onSelectRisk: (RiskItem) -> Void
    var onFocusUnlocatedRisk: (RiskItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ContractMetaCard(
                title: documentTitle,
                attachmentFilename: attachmentFilename,
                characterCount: contractCharacterCount,
                riskCount: displayedRiskCount
            )

            if !sourceMap.unmatchedRisks.isEmpty {
                UnlocatedRiskNotice(risks: sourceMap.unmatchedRisks) { risk in
                    onFocusUnlocatedRisk(risk)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(sourceMap.paragraphs) { paragraph in
                    SourceParagraphBlock(
                        paragraph: paragraph,
                        isConfirmed: paragraph.risks.contains(where: { confirmedRiskIDs.contains($0.id.uuidString) }),
                        isFlashing: flashParagraphID == paragraph.id,
                        onSelectRisk: onSelectRisk
                    )
                    .id(paragraph.id)
                }
            }
            .padding(16)
            .background(QiheColor.neutral0.opacity(0.98))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(QiheColor.glassStroke.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 9, x: 0, y: 3)
        }
    }

    private var contractCharacterCount: Int {
        sourceMap.paragraphs
            .map(\.text)
            .joined()
            .unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
            .count
    }
}

private struct SourceParagraphBlock: View {
    let paragraph: AnnotatedSourceParagraph
    var isConfirmed = false
    var isFlashing = false
    let onSelectRisk: (RiskItem) -> Void

    @State private var flashOpacity: Double = 0

    var body: some View {
        Group {
            if let primaryRisk = paragraph.primaryRisk {
                Button {
                    onSelectRisk(primaryRisk)
                } label: { content }
                .buttonStyle(.plain)
                .accessibilityLabel("有风险段落，\(primaryRisk.riskLevel.label)")
            } else {
                content
            }
        }
        .overlay(alignment: .topLeading) {
            if isFlashing {
                RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                    .fill(QiheColor.amber.opacity(flashOpacity))
                    .allowsHitTesting(false)
            }
        }
        .onChange(of: isFlashing) { _, newValue in
            guard newValue else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                flashOpacity = 0.35
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.45)) {
                    flashOpacity = 0
                }
            }
        }
    }

    private var dominantLevel: RiskLevel {
        paragraph.primaryRisk?.riskLevel ?? .pending
    }

    private var sideBarColor: Color {
        isConfirmed ? QiheColor.pine : sourceRiskColor(for: dominantLevel)
    }

    private var bgColor: Color {
        isConfirmed ? QiheColor.pineSoft : sourceRiskBackgroundColor(for: dominantLevel)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 10) {
            if paragraph.primaryRisk != nil {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(sideBarColor)
                    .frame(width: 4)
                    .padding(.vertical, 1)
            }

            VStack(alignment: .leading, spacing: paragraph.risks.isEmpty ? 0 : 8) {
                if !paragraph.risks.isEmpty {
                    FlowLayout(spacing: 6) {
                        if isConfirmed {
                            SourceRiskStatePill(title: "已修改", color: QiheColor.safeGreen, background: QiheColor.safeGreenSoft)
                        } else {
                            ForEach(Array(paragraph.risks.prefix(3))) { risk in
                                SourceRiskLevelPill(risk: risk)
                            }
                        }

                        if paragraph.risks.count > 3 && !isConfirmed {
                            Text("+\(paragraph.risks.count - 3)")
                                .font(QiheFont.caption(size: 10.5, weight: .semibold))
                                .foregroundStyle(sideBarColor)
                                .padding(.horizontal, 7)
                                .frame(height: 23)
                                .background(QiheColor.card.opacity(0.82))
                                .clipShape(Capsule())
                        }
                    }
                }

                Text(paragraph.text)
                    .font(QiheFont.contractDocument(size: 15))
                    .foregroundStyle(QiheColor.inkSoft)
                    .lineSpacing(QiheTypography.bodyLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, paragraph.primaryRisk == nil ? 0 : 12)
        .padding(.vertical, paragraph.primaryRisk == nil ? 2 : 12)
        .padding(.bottom, paragraph.primaryRisk == nil ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(paragraph.primaryRisk == nil ? Color.clear : bgColor.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(paragraph.primaryRisk == nil ? Color.clear : sideBarColor.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ContractMetaCard: View {
    let title: String
    var attachmentFilename: String?
    let characterCount: Int
    let riskCount: Int

    var body: some View {
        QiheGlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(QiheFont.h3(size: 17, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    Spacer(minLength: 8)

                    QiheRiskBadge(level: riskCount > 0 ? .pending : .low, text: "\(riskCount) 风险")
                }

                Text("共 \(formattedCharacterCount) 字 · 审查视图 · 这份合同有 \(riskCount) 处需要注意")
                    .font(QiheFont.micro(size: 11, weight: .medium))
                    .foregroundStyle(QiheColor.inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.86)

                if let attachmentFilename {
                    Label(attachmentFilename, systemImage: "doc.text")
                        .font(QiheFont.micro(size: 10.5, weight: .medium))
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
        }
    }

    private var formattedCharacterCount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: characterCount)) ?? "\(characterCount)"
    }
}

/// 风险等级 → 原文段落侧边栏/背景色
private func sourceRiskColor(for level: RiskLevel) -> Color {
    switch level {
    case .high:
        return Color(hex: 0xEA580C)
    case .medium:
        return QiheColor.riskOrange
    case .low:
        return QiheColor.brandBlue
    case .pending, .unknown:
        return QiheColor.navy
    }
}

/// 风险等级 → 原文段落背景色（浅色版）
private func sourceRiskBackgroundColor(for level: RiskLevel) -> Color {
    switch level {
    case .high:
        return Color(hex: 0xFFF5ED)
    case .medium:
        return QiheColor.riskOrangeSoft
    case .low:
        return QiheColor.infoBlueSoft
    case .pending, .unknown:
        return QiheColor.navySoft
    }
}

private struct SourceRiskLevelPill: View {
    let risk: RiskItem

    var body: some View {
        QiheRiskBadge(level: risk.riskLevel, text: label)
    }

    private var label: String {
        if let clause = risk.clauseTitle?.nilIfBlank ?? risk.clauseId?.nilIfBlank {
            return "\(risk.riskLevel.label) · \(clause.truncated(to: 10))"
        }
        return "\(risk.riskLevel.label)条款"
    }
}

private struct SourceRiskStatePill: View {
    let title: String
    let color: Color
    let background: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10.5, weight: .semibold))
            Text(title)
        }
        .font(QiheFont.caption(size: 10.5, weight: .semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.82)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))
    }
}

private enum SourceRiskLocator {
    // MARK: - 后端 blocks 驱动（任务三）

    /// 使用后端 blocks 构建 SourceRiskMap
    /// - Parameters:
    ///   - blocks: 后端返回的结构化段落块
    ///   - risks: 审查结果中的风险列表
    /// - Returns: 带风险标注的段落映射
    static func annotate(blocks: [ContractBlock], risks: [RiskItem]) -> SourceRiskMap {
        // 构建 riskId → RiskItem 的快速查找表
        let riskById = Dictionary(grouping: risks, by: { $0.id.uuidString })
            .compactMapValues { $0.first }

        var unmatchedRiskIDs = Set(riskById.keys)
        var annotatedParagraphs: [AnnotatedSourceParagraph] = []

        for (index, block) in blocks.enumerated() {
            let blockRiskIds = block.riskIds ?? []
            var matchedRisks: [RiskItem] = []

            for riskId in blockRiskIds {
                if let risk = riskById[riskId] {
                    matchedRisks.append(risk)
                    unmatchedRiskIDs.remove(riskId)
                }
            }

            annotatedParagraphs.append(
                AnnotatedSourceParagraph(
                    id: index,
                    text: block.text,
                    risks: matchedRisks.sortedForSourceDisplay
                )
            )
        }

        let unmatchedRisks = unmatchedRiskIDs.compactMap { riskById[$0] }
            .sortedForSourceDisplay

        return SourceRiskMap(paragraphs: annotatedParagraphs, unmatchedRisks: unmatchedRisks)
    }

    // MARK: - 前端本地分段（回退）

    static func annotate(result: ReviewResult, sourceTextOverride: String? = nil) -> SourceRiskMap {
        let text = sourceTextOverride ?? result.sourceText
        let paragraphs = sourceParagraphs(from: text)
        var risksByParagraph: [Int: [RiskItem]] = [:]
        var unmatchedRisks: [RiskItem] = []

        for risk in result.risks {
            if let paragraphID = matchedParagraphID(for: risk, in: paragraphs) {
                risksByParagraph[paragraphID, default: []].append(risk)
            } else {
                unmatchedRisks.append(risk)
            }
        }

        let annotatedParagraphs = paragraphs.map { paragraph in
            let risks = (risksByParagraph[paragraph.id] ?? []).sortedForSourceDisplay
            return AnnotatedSourceParagraph(id: paragraph.id, text: paragraph.text, risks: risks)
        }

        return SourceRiskMap(paragraphs: annotatedParagraphs, unmatchedRisks: unmatchedRisks)
    }

    private static func matchedParagraphID(for risk: RiskItem, in paragraphs: [SourceTextParagraph]) -> Int? {
        if let id = offsetParagraphID(for: risk, in: paragraphs) {
            return id
        }

        if let id = uniqueParagraphID(
            for: originalExcerptCandidates(from: risk),
            in: paragraphs,
            minimumLength: 8,
            allowReverseContainment: true
        ) {
            return id
        }

        if let id = uniqueParagraphID(for: clauseCandidates(from: risk), in: paragraphs, minimumLength: 3) {
            return id
        }

        if let id = uniqueParagraphID(
            for: originalTextCandidates(from: risk),
            in: paragraphs,
            minimumLength: 8,
            allowReverseContainment: true
        ) {
            return id
        }

        if let id = uniqueParagraphID(for: quotedFieldCandidates(from: risk), in: paragraphs, minimumLength: 8) {
            return id
        }

        return uniqueParagraphID(for: longFieldCandidates(from: risk), in: paragraphs, minimumLength: 14)
    }

    private static func sourceParagraphs(from sourceText: String) -> [SourceTextParagraph] {
        var searchStart = sourceText.startIndex

        return splitSourceText(sourceText).enumerated().map { index, text in
            let searchRange = searchStart..<sourceText.endIndex
            guard let range = sourceText.range(of: text, options: [], range: searchRange) else {
                return SourceTextParagraph(id: index, text: text)
            }

            searchStart = range.upperBound
            return SourceTextParagraph(
                id: index,
                text: text,
                startOffset: range.lowerBound.utf16Offset(in: sourceText),
                endOffset: range.upperBound.utf16Offset(in: sourceText)
            )
        }
    }

    private static func offsetParagraphID(for risk: RiskItem, in paragraphs: [SourceTextParagraph]) -> Int? {
        guard let startOffset = risk.startOffset,
              let endOffset = risk.endOffset,
              startOffset >= 0,
              endOffset > startOffset else {
            return nil
        }

        let scoredParagraphs = paragraphs.compactMap { paragraph -> (id: Int, overlap: Int)? in
            guard let paragraphStart = paragraph.startOffset,
                  let paragraphEnd = paragraph.endOffset,
                  paragraphEnd > paragraphStart else {
                return nil
            }

            let overlap = max(0, min(endOffset, paragraphEnd) - max(startOffset, paragraphStart))
            guard overlap > 0 else {
                return nil
            }
            return (paragraph.id, overlap)
        }

        guard !scoredParagraphs.isEmpty else {
            return nil
        }
        if scoredParagraphs.count == 1 {
            return scoredParagraphs[0].id
        }

        let maxOverlap = scoredParagraphs.map(\.overlap).max() ?? 0
        let winners = scoredParagraphs.filter { $0.overlap == maxOverlap }
        return winners.count == 1 ? winners[0].id : nil
    }

    private static func splitSourceText(_ text: String) -> [String] {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmedForInput

        guard !normalizedText.isEmpty else {
            return []
        }

        let clauseSegments = splitAtMatches(
            in: normalizedText,
            pattern: #"(^|\n|[。；;])\s*(第\s*[一二三四五六七八九十百千万零〇两0-9]+\s*条\s*[：:、.．]?)"#,
            captureGroup: 2
        )
        if clauseSegments.count > 1 {
            return clauseSegments
        }

        let numberedSegments = splitAtMatches(
            in: normalizedText,
            pattern: #"(^|\n)\s*([一二三四五六七八九十0-9]+[、.．])"#,
            captureGroup: 2
        )
        if numberedSegments.count > 1 {
            return numberedSegments
        }

        let blankSeparated = normalizedText
            .replacingOccurrences(of: #"\n\s*\n+"#, with: "\u{000B}", options: .regularExpression)
            .components(separatedBy: "\u{000B}")
            .compactMap(\.nilIfBlank)
        if blankSeparated.count > 1 {
            return blankSeparated
        }

        let lineSeparated = normalizedText
            .components(separatedBy: "\n")
            .compactMap(\.nilIfBlank)

        return lineSeparated.isEmpty ? [normalizedText] : lineSeparated
    }

    private static func splitAtMatches(in text: String, pattern: String, captureGroup: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
        var starts = matches.compactMap { match -> String.Index? in
            guard match.numberOfRanges > captureGroup,
                  let range = Range(match.range(at: captureGroup), in: text) else {
                return nil
            }
            return range.lowerBound
        }
        starts.sort()
        starts = starts.reduce(into: []) { uniqueStarts, start in
            if uniqueStarts.last != start {
                uniqueStarts.append(start)
            }
        }

        guard !starts.isEmpty else {
            return []
        }

        var boundaries = starts
        if let first = starts.first, first > text.startIndex {
            boundaries.insert(text.startIndex, at: 0)
        }
        boundaries.append(text.endIndex)

        return boundaries.indices.dropLast().compactMap { index in
            let start = boundaries[index]
            let end = boundaries[boundaries.index(after: index)]
            return String(text[start..<end]).nilIfBlank
        }
    }

    private static func uniqueParagraphID(
        for candidates: [String],
        in paragraphs: [SourceTextParagraph],
        minimumLength: Int,
        allowReverseContainment: Bool = false
    ) -> Int? {
        for candidate in orderedUnique(candidates) {
            let normalizedCandidate = candidate.sourceMatchNormalized
            guard normalizedCandidate.count >= minimumLength else {
                continue
            }

            let matchedIDs = paragraphs.compactMap { paragraph -> Int? in
                if paragraph.normalizedText.contains(normalizedCandidate) {
                    return paragraph.id
                }

                if allowReverseContainment,
                   paragraph.normalizedText.count >= minimumLength,
                   normalizedCandidate.contains(paragraph.normalizedText) {
                    return paragraph.id
                }

                return nil
            }

            let uniqueIDs = Array(Set(matchedIDs))
            if uniqueIDs.count == 1 {
                return uniqueIDs[0]
            }
        }

        return nil
    }

    private static func clauseCandidates(from risk: RiskItem) -> [String] {
        var candidates: [String] = []

        if let clauseTitle = risk.clauseTitle?.nilIfBlank {
            candidates.append(clauseTitle)
            candidates.append(contentsOf: clauseNumberCandidates(in: clauseTitle))
        }

        if let clauseId = risk.clauseId?.nilIfBlank {
            candidates.append(contentsOf: clauseIDCandidates(from: clauseId))
        }

        if let clause = risk.clause?.nilIfBlank {
            candidates.append(clause)
            candidates.append(contentsOf: clauseNumberCandidates(in: clause))
            candidates.append(contentsOf: regexCaptures(
                in: clause,
                pattern: #"(^|\s)([一二三四五六七八九十0-9]+[、.．])"#,
                captureGroup: 2
            ))
        }

        return candidates
    }

    private static func originalExcerptCandidates(from risk: RiskItem) -> [String] {
        guard let originalExcerpt = risk.originalExcerpt?.nilIfBlank else {
            return []
        }

        return [originalExcerpt] + sentenceSnippets(in: originalExcerpt)
    }

    private static func originalTextCandidates(from risk: RiskItem) -> [String] {
        guard let originalText = risk.originalText?.nilIfBlank else {
            return []
        }

        return [originalText] + quotedSnippets(in: originalText) + sentenceSnippets(in: originalText)
    }

    private static func quotedFieldCandidates(from risk: RiskItem) -> [String] {
        [
            risk.originalText,
            risk.riskTitle,
            risk.suggestedReplacement,
            risk.risk,
            risk.riskAnalysis
        ]
        .compactMap { $0?.nilIfBlank }
        .flatMap { quotedSnippets(in: $0) + sentenceSnippets(in: $0) }
    }

    private static func longFieldCandidates(from risk: RiskItem) -> [String] {
        [
            risk.originalText,
            risk.riskTitle,
            risk.suggestedReplacement,
            risk.risk,
            risk.riskAnalysis
        ]
        .compactMap { $0?.nilIfBlank }
    }

    private static func quotedSnippets(in text: String) -> [String] {
        regexCaptures(
            in: text,
            pattern: #"[“"「『']([^”"」』']{4,})[”"」』']"#,
            captureGroup: 1
        )
    }

    private static func sentenceSnippets(in text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "。；;！!？?\n"))
            .compactMap(\.nilIfBlank)
    }

    private static func clauseNumberCandidates(in text: String) -> [String] {
        let numbers = regexCaptures(
            in: text,
            pattern: #"第\s*([一二三四五六七八九十百千万零〇两0-9]+)\s*条"#,
            captureGroup: 1
        )

        return numbers.flatMap { rawNumber -> [String] in
            var candidates = ["第\(rawNumber)条"]
            let normalizedNumber = rawNumber.sourceMatchNormalized
            if let number = Int(normalizedNumber), let chinese = chineseNumberText(for: number) {
                candidates.append("第\(chinese)条")
            } else if let number = chineseNumberValue(normalizedNumber) {
                candidates.append("第\(number)条")
            }
            return candidates
        }
    }

    private static func clauseIDCandidates(from text: String) -> [String] {
        let cleaned = text.trimmedForInput
        var candidates = clauseNumberCandidates(in: cleaned)

        if let number = Int(cleaned), let chinese = chineseNumberText(for: number) {
            candidates.append("第\(number)条")
            candidates.append("第\(chinese)条")
        } else if let number = chineseNumberValue(cleaned.sourceMatchNormalized) {
            candidates.append("第\(number)条")
            if let chinese = chineseNumberText(for: number) {
                candidates.append("第\(chinese)条")
            }
        } else if cleaned.sourceMatchNormalized.count >= 3 {
            candidates.append(cleaned)
        }

        let trailingNumbers = regexCaptures(
            in: cleaned,
            pattern: #"([0-9]+)$"#,
            captureGroup: 1
        )
        for rawNumber in trailingNumbers {
            guard let number = Int(rawNumber) else {
                continue
            }
            candidates.append("第\(number)条")
            if let chinese = chineseNumberText(for: number) {
                candidates.append("第\(chinese)条")
            }
        }

        return candidates
    }

    private static func regexCaptures(in text: String, pattern: String, captureGroup: Int) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        return regex.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
            .compactMap { match -> String? in
                guard match.numberOfRanges > captureGroup,
                      let range = Range(match.range(at: captureGroup), in: text) else {
                    return nil
                }
                return String(text[range]).nilIfBlank
            }
    }

    private static func orderedUnique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for value in values {
            let key = value.sourceMatchNormalized
            guard !key.isEmpty, !seen.contains(key) else {
                continue
            }
            seen.insert(key)
            result.append(value)
        }

        return result
    }

    private static func chineseNumberText(for number: Int) -> String? {
        let digits = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        guard number > 0, number < 100 else {
            return nil
        }

        if number < 10 {
            return digits[number]
        }
        if number == 10 {
            return "十"
        }

        let tens = number / 10
        let ones = number % 10
        let prefix = tens == 1 ? "十" : "\(digits[tens])十"
        return ones == 0 ? prefix : "\(prefix)\(digits[ones])"
    }

    private static func chineseNumberValue(_ text: String) -> Int? {
        let digits: [Character: Int] = [
            "零": 0,
            "〇": 0,
            "一": 1,
            "二": 2,
            "两": 2,
            "三": 3,
            "四": 4,
            "五": 5,
            "六": 6,
            "七": 7,
            "八": 8,
            "九": 9
        ]
        let normalized = text.replacingOccurrences(of: "兩", with: "两")

        if normalized == "十" {
            return 10
        }

        if normalized.count == 1, let character = normalized.first, let value = digits[character], value > 0 {
            return value
        }

        guard let tenIndex = normalized.firstIndex(of: "十") else {
            return nil
        }

        let beforeTen = normalized[..<tenIndex]
        let afterTen = normalized[normalized.index(after: tenIndex)...]

        let tens: Int
        if beforeTen.isEmpty {
            tens = 1
        } else if beforeTen.count == 1, let character = beforeTen.first, let value = digits[character], value > 0 {
            tens = value
        } else {
            return nil
        }

        let ones: Int
        if afterTen.isEmpty {
            ones = 0
        } else if afterTen.count == 1, let character = afterTen.first, let value = digits[character] {
            ones = value
        } else {
            return nil
        }

        return tens * 10 + ones
    }
}

private extension Array where Element == RiskItem {
    var sortedForSourceDisplay: [RiskItem] {
        sorted {
            if $0.riskLevel.sourceDisplayRank == $1.riskLevel.sourceDisplayRank {
                return $0.displayTitle < $1.displayTitle
            }
            return $0.riskLevel.sourceDisplayRank < $1.riskLevel.sourceDisplayRank
        }
    }
}

private extension RiskLevel {
    var sourceDisplayRank: Int {
        switch self {
        case .high:
            return 0
        case .medium:
            return 1
        case .low:
            return 2
        case .pending:
            return 3
        case .unknown:
            return 4
        }
    }
}

private extension String {
    var sourceMatchNormalized: String {
        let folded = folding(options: [.caseInsensitive, .widthInsensitive], locale: .current).lowercased()
        var normalized = ""
        for scalar in folded.unicodeScalars {
            guard !CharacterSet.whitespacesAndNewlines.contains(scalar),
                  !CharacterSet.punctuationCharacters.contains(scalar),
                  !CharacterSet.symbols.contains(scalar) else {
                continue
            }
            normalized.unicodeScalars.append(scalar)
        }
        return normalized
    }
}

private struct RiskReportCard: View {
    let risk: RiskItem
    var isHighlighted = false
    let onShowSuggestion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Text(risk.riskLevel.label)
                    .font(QiheFont.caption(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(referenceTint)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

                Text(clauseHeading)
                    .font(QiheFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.84)

                Spacer(minLength: 0)
            }

            Text(originalContent)
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xF4F6FA))
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            if let analysis = risk.displayAnalysis?.nilIfBlank {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(referenceTint)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("风险描述")
                            .font(QiheFont.caption(size: 12.5, weight: .semibold))
                            .foregroundStyle(referenceTint)

                        Text(analysis)
                            .font(QiheFont.body(size: 13.5))
                            .foregroundStyle(referenceTextTint)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 1)
                .padding(.horizontal, 1)
            }

            HStack {
                Spacer(minLength: 0)

                Button(action: onShowSuggestion) {
                    Label("AI 修改建议", systemImage: "square.and.pencil")
                        .font(QiheFont.caption(size: 12, weight: .semibold))
                        .foregroundStyle(QiheColor.brandBlue.opacity(0.72))
                        .padding(.horizontal, 12)
                        .frame(height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(QiheColor.brandBlue.opacity(0.24), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .padding(.leading, 4)
        .background(isHighlighted ? QiheColor.infoBlueSoft.opacity(0.76) : QiheColor.neutral0.opacity(0.98))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isHighlighted ? QiheColor.brandBlue : referenceTint)
                .frame(width: isHighlighted ? 5 : 4)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(
                    isHighlighted ? QiheColor.brandBlue.opacity(0.42) : referenceTint.opacity(0.28),
                    lineWidth: isHighlighted ? 1.5 : 1
                )
        )
        .shadow(color: isHighlighted ? QiheColor.shadowBlue.opacity(0.18) : QiheColor.shadowNavySoft, radius: 9, x: 0, y: 3)
        .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }

    private var clauseHeading: String {
        risk.clauseTitle?.nilIfBlank
            ?? risk.clauseId?.nilIfBlank
            ?? risk.displayTitle
    }

    private var originalContent: String {
        risk.originalExcerpt?.nilIfBlank
            ?? risk.originalText?.nilIfBlank
            ?? risk.clause?.nilIfBlank
            ?? "暂无可展示的条款原文。"
    }

    private var referenceTint: Color {
        switch risk.riskLevel {
        case .high:
            return Color(hex: 0xEA580C)
        case .medium:
            return QiheColor.riskOrange
        case .low:
            return QiheColor.brandBlue
        case .pending, .unknown:
            return QiheColor.muted
        }
    }

    private var referenceTextTint: Color {
        switch risk.riskLevel {
        case .high:
            return Color(hex: 0x9A3412)
        case .medium:
            return Color(hex: 0x92400E)
        case .low:
            return Color(hex: 0x1E40AF)
        case .pending, .unknown:
            return QiheColor.inkSoft
        }
    }
}

private struct RiskReportSection: View {
    let title: String
    let icon: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.brandBlue)

            Text(text)
                .font(QiheFont.body(size: 13.5))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.infoBlueSoft.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
    }
}

private struct RiskReplacementPreview: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("建议")
                .font(QiheFont.caption(size: 11, weight: .semibold))
                .foregroundStyle(QiheColor.safeGreen)
                .padding(.horizontal, 7)
                .frame(height: 24)
                .background(QiheColor.safeGreenSoft)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))

            Text(text)
                .font(QiheFont.body(size: 13.5))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.safeGreenSoft.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
    }
}

struct SubjectFactsPanel: View {
    let result: ReviewResult

    var body: some View {
        let facts = result.parties?.subjectFacts ?? []
        let missingCoreFields = ContractSubjectField.coreFields.filter { field in
            !facts.contains { $0.field == field }
        }

        VStack(alignment: .leading, spacing: 12) {
            if facts.isEmpty {
                EmptySubjectBox()
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(facts) { fact in
                        HStack(spacing: 4) {
                            Text(fact.label)
                                .foregroundStyle(QiheColor.muted)
                            Text(fact.value)
                                .fontWeight(.semibold)
                                .foregroundStyle(QiheColor.ink)
                        }
                        .font(QiheFont.caption(size: 12))
                        .padding(.horizontal, 11)
                        .frame(height: 30)
                        .background(QiheColor.card)
                        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                                .stroke(QiheColor.line, lineWidth: 1)
                        )
                    }
                }

                if !missingCoreFields.isEmpty {
                    PartialSubjectNotice(missingFields: missingCoreFields)
                }
            }
        }
    }
}

private struct PartialSubjectNotice: View {
    let missingFields: [ContractSubjectField]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("部分信息待补充：\(fieldLabels)")
                .font(QiheFont.body(size: 13, weight: .semibold))
                .foregroundStyle(QiheColor.amber)

            Text("未识别到\(fieldLabels)，请确认合同文本是否完整。")
                .font(QiheFont.caption(size: 11.5))
                .foregroundStyle(QiheColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(QiheColor.amber.opacity(0.32), lineWidth: 1)
        )
    }

    private var fieldLabels: String {
        missingFields.map(\.label).joined(separator: "、")
    }
}

struct EmptySubjectBox: View {
    var body: some View {
        VStack(spacing: 10) {
            QiheLogoMark(size: 30)
                .frame(width: 46, height: 46)
                .background(QiheColor.infoBlueSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("未识别到乙方、金额或期限等信息，请确认合同文本是否完整。")
                .font(QiheFont.body(size: 12.5))
                .foregroundStyle(QiheColor.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(QiheColor.card.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .strokeBorder(QiheColor.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }
}

struct FlowLayout: Layout {
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

// MARK: - 风险详情弹窗

struct RiskDetailSheet: View {
    let risk: RiskItem
    let paragraphText: String
    let isConfirmed: Bool
    let onDismiss: () -> Void
    let onConfirm: (_ beforeText: String, _ afterText: String) -> Void
    let onEdit: () -> Void

    private var originalContent: String {
        risk.originalExcerpt?.nilIfBlank
            ?? risk.originalText?.nilIfBlank
            ?? paragraphText
    }

    private var suggestionContent: String? {
        risk.suggestedReplacement?.nilIfBlank
            ?? risk.revisionSuggestion?.nilIfBlank
            ?? risk.suggestion?.nilIfBlank
    }

    var body: some View {
        ZStack {
            QiheColor.pageBackgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    RiskSheetHandle()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("修改建议")
                            .font(QiheFont.title(size: 20))
                            .foregroundStyle(QiheColor.ink)

                        Text(isConfirmed ? "这条建议已覆盖原文，可继续查看或编辑。" : "我按当前立场整理了一版，可以直接覆盖原文。")
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.inkSoft)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .center, spacing: 8) {
                        QiheRiskBadge(level: risk.riskLevel, text: "\(risk.riskLevel.label) · \(risk.displayTitle)")

                        if isConfirmed {
                            QiheStatusPill(
                                text: "已修改",
                                color: QiheColor.safeGreen,
                                background: QiheColor.safeGreenSoft
                            )
                        }
                    }

                    if let legalBasis = risk.displayLegalBasis {
                        RiskSheetInfoRow(
                            title: "涉及条款",
                            systemImage: "text.book.closed",
                            content: legalBasis
                        )
                    }

                    RiskSheetTextBlock(
                        title: "原文内容",
                        content: originalContent,
                        tint: risk.riskLevel.foreground,
                        background: risk.riskLevel.background.opacity(0.62),
                        systemImage: "doc.text"
                    )

                    if let suggestionContent {
                        RiskSheetTextBlock(
                            title: "AI 修改建议",
                            content: suggestionContent,
                            tint: QiheColor.brandBlue,
                            background: QiheColor.infoBlueSoft.opacity(0.72),
                            systemImage: "sparkles"
                        )
                    }

                    if let analysis = risk.displayAnalysis {
                        RiskSheetInfoRow(
                            title: "风险分析",
                            systemImage: "magnifyingglass",
                            content: analysis
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    QihePrimaryButton(
                        title: "确认覆盖原文",
                        systemImage: "checkmark",
                        isDisabled: suggestionContent?.trimmedForInput.isEmpty ?? true
                    ) {
                        guard let afterText = suggestionContent?.trimmedForInput,
                              !afterText.isEmpty else { return }
                        onConfirm(originalContent, afterText)
                    }

                    HStack(spacing: 10) {
                        QiheSecondaryButton(title: "编辑建议", systemImage: "square.and.pencil") {
                            onEdit()
                        }

                        QiheSecondaryButton(title: "取消") {
                            onDismiss()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
        }
        .background(QiheColor.neutral0)
    }
}

private struct RiskSheetHandle: View {
    var body: some View {
        Capsule()
            .fill(QiheColor.neutral300)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
    }
}

private struct RiskSheetInfoRow: View {
    let title: String
    let systemImage: String
    let content: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.brandBlue)
                .frame(width: 22, height: 22)
                .background(QiheColor.infoBlueSoft)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QiheFont.caption(size: 11, weight: .semibold))
                    .foregroundStyle(QiheColor.muted)
                Text(content)
                    .font(QiheFont.body(size: 13))
                    .foregroundStyle(QiheColor.inkSoft)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(QiheColor.neutral0.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous)
                .stroke(QiheColor.glassStroke, lineWidth: 1)
        )
    }
}

private struct RiskSheetTextBlock: View {
    let title: String
    let content: String
    let tint: Color
    let background: Color
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
            }
            .font(QiheFont.caption(size: 11, weight: .semibold))
            .foregroundStyle(tint)

            Text(content)
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 12)
                .padding(.leading, 14)
                .padding(.trailing, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint)
                        .frame(width: 4)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous)
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        }
    }
}

// MARK: - 风险编辑弹窗

/// 默认填入优先级：suggestedReplacement → revisionSuggestion → paragraphText
struct RiskEditSheet: View {
    let risk: RiskItem
    let paragraphText: String
    let onDismiss: () -> Void
    let onConfirm: (_ beforeText: String, _ afterText: String) -> Void

    @State private var editedText: String
    @FocusState private var isTextEditorFocused: Bool

    private var beforeText: String {
        risk.originalExcerpt?.nilIfBlank
            ?? risk.originalText?.nilIfBlank
            ?? paragraphText
    }

    init(
        risk: RiskItem,
        paragraphText: String,
        onDismiss: @escaping () -> Void,
        onConfirm: @escaping (_ beforeText: String, _ afterText: String) -> Void
    ) {
        self.risk = risk
        self.paragraphText = paragraphText
        self.onDismiss = onDismiss
        self.onConfirm = onConfirm

        let defaultText = risk.suggestedReplacement?.nilIfBlank
            ?? risk.revisionSuggestion?.nilIfBlank
            ?? risk.suggestion?.nilIfBlank
            ?? paragraphText
        _editedText = State(initialValue: defaultText)
    }

    var body: some View {
        ZStack {
            QiheColor.pageBackgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RiskSheetHandle()

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("编辑修改建议")
                                        .font(QiheFont.title(size: 20))
                                        .foregroundStyle(QiheColor.ink)
                                    Text("确认后将替换原文对应段落。")
                                        .font(QiheFont.body(size: 13))
                                        .foregroundStyle(QiheColor.muted)
                                }

                                Spacer(minLength: 8)

                                QiheRiskBadge(level: risk.riskLevel)
                            }

                            Text(risk.displayTitle)
                                .font(QiheFont.caption(size: 12, weight: .semibold))
                                .foregroundStyle(QiheColor.inkSoft)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        RiskSheetTextBlock(
                            title: "原文内容",
                            content: beforeText,
                            tint: risk.riskLevel.foreground,
                            background: risk.riskLevel.background.opacity(0.62),
                            systemImage: "doc.text"
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Label("AI 修改建议", systemImage: "sparkles")
                                .font(QiheFont.caption(size: 11, weight: .semibold))
                                .foregroundStyle(QiheColor.brandBlue)

                            TextEditor(text: $editedText)
                                .font(QiheFont.body(size: 14))
                                .foregroundStyle(QiheColor.ink)
                                .focused($isTextEditorFocused)
                                .scrollContentBackground(.hidden)
                                .padding(.vertical, 8)
                                .padding(.leading, 10)
                                .padding(.trailing, 8)
                                .frame(minHeight: 168)
                                .background(QiheColor.infoBlueSoft.opacity(0.72))
                                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))
                                .overlay(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(QiheColor.brandBlue)
                                        .frame(width: 4)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous)
                                        .stroke(QiheColor.brandBlue.opacity(0.22), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }

                VStack(spacing: 8) {
                    QihePrimaryButton(
                        title: "确认覆盖原文",
                        systemImage: "checkmark",
                        isDisabled: editedText.trimmedForInput.isEmpty
                    ) {
                        let trimmed = editedText.trimmedForInput
                        guard !trimmed.isEmpty else { return }
                        onConfirm(beforeText, trimmed)
                    }

                    QiheSecondaryButton(title: "取消") {
                        onDismiss()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
            }
        }
        .background(QiheColor.neutral0)
        .onAppear { isTextEditorFocused = true }
    }
}
