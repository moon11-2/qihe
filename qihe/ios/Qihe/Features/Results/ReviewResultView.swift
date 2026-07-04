import SwiftUI

struct ReviewResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID
    @State private var selectedTab: ReviewResultTab = .risks
    @State private var isExporting = false
    @State private var shareDocument: ShareDocument?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let payload = historyStore.record(id: recordId)?.reviewPayload {
                VStack(spacing: 0) {
                    tabBar
                    Divider().background(QiheColor.line)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
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
                        .padding(20)
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
        .navigationTitle("审查结果")
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
        .sheet(item: $shareDocument) { document in
            ShareSheet(document: document)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 22) {
            ForEach(ReviewResultTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(QiheFont.title(size: 15))
                        .foregroundStyle(selectedTab == tab ? QiheColor.navy : QiheColor.muted)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(QiheColor.navy)
                                    .frame(height: 2.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .background(QiheColor.paper)
    }

    private func sourceTab(_ payload: ReviewHistoryPayload) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            QiheSectionHeader(title: "原文", subtitle: payload.attachment?.filename)

            PaperCard {
                Text(payload.result.sourceText)
                    .font(QiheFont.body(size: 14))
                    .foregroundStyle(QiheColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func riskTab(_ result: ReviewResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            reportHead(result)
            statStrip(result)

            if result.risks.isEmpty {
                PaperCard {
                    EmptyStateView(
                        title: "暂无风险条目",
                        detail: "后端未返回风险列表时，会保留摘要、审查依据和原文。"
                    )
                }
            } else {
                ForEach(result.risks) { risk in
                    RiskReportCard(risk: risk)
                }
            }
        }
    }

    private func reportHead(_ result: ReviewResult) -> some View {
        PaperCard {
            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(result.displayTitle)
                        .font(QiheFont.title(size: 20))
                        .foregroundStyle(QiheColor.ink)

                    Text(result.summary?.nilIfBlank ?? "审查报告已生成，请重点查看风险卡片。")
                        .font(QiheFont.body(size: 13))
                        .foregroundStyle(QiheColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.trailing, 70)

                    HStack(spacing: 5) {
                        Image(systemName: "text.book.closed")
                            .font(.system(size: 13, weight: .medium))
                        Text("审查依据：\(result.reviewBasis?.nilIfBlank ?? "中国大陆现行法律")")
                            .font(QiheFont.caption(size: 11))
                    }
                    .foregroundStyle(QiheColor.navy)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ReviewRiskGradeStamp(level: result.riskLevel ?? .pending)
            }
        }
    }

    private func statStrip(_ result: ReviewResult) -> some View {
        HStack(spacing: 0) {
            ReviewStatCell(value: "\(result.displayedRiskCount)", label: "风险数量")
            ReviewStatCell(value: "\(result.score ?? scoreFallback(for: result.riskLevel))", label: "综合评分")
            ReviewStatCell(value: gradeLetter(for: result.riskLevel), label: "风险等级", color: (result.riskLevel ?? .pending).foreground)
        }
        .background(QiheColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(QiheColor.lineStrong, lineWidth: 1)
        )
    }

    private func subjectsTab(_ result: ReviewResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            QiheSectionHeader(title: "主体", subtitle: "合同当事人与关键信息")

            SubjectFactsPanel(result: result)

            QiheSecondaryButton(title: "查看主体详情", systemImage: "person.text.rectangle") {
                appState.path.append(.subject(recordId: recordId))
            }
        }
    }

    private func exportWord(_ payload: ReviewHistoryPayload) async {
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let url = try await appState.apiClient.exportReviewWord(
                title: payload.result.displayTitle,
                payload: payload.result
            )
            shareDocument = ShareDocument(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
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
            return "主体"
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
                .font(QiheFont.title(size: 8.5))
        }
        .foregroundStyle(level.foreground)
        .frame(width: 58, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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

private struct RiskReportCard: View {
    let risk: RiskItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(risk.displayTitle)
                    .font(QiheFont.title(size: 15))
                    .foregroundStyle(QiheColor.ink)
                    .padding(.trailing, 58)

                Spacer()
            }

            if let clause = risk.clause?.nilIfBlank {
                Text("涉及条款 · \(clause)")
                    .font(QiheFont.caption(size: 11))
                    .foregroundStyle(QiheColor.muted)
            }

            if let analysis = risk.displayAnalysis {
                LabeledText(label: "风险分析", text: analysis)
            }

            if let suggestion = risk.displaySuggestion {
                LabeledText(label: "修订建议", text: suggestion)
            }

            if let replacement = risk.suggestedReplacement?.nilIfBlank {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("修改")
                        .font(QiheFont.title(size: 11))
                        .foregroundStyle(QiheColor.seal)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(QiheColor.seal, lineWidth: 1)
                        )

                    Text(replacement)
                        .font(QiheFont.body(size: 12.5))
                        .foregroundStyle(QiheColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }

            if let legalBasis = risk.displayLegalBasis {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 14, weight: .medium))
                    Text("法条依据 \(legalBasis)")
                        .font(QiheFont.caption(size: 11.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(QiheColor.navy)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(QiheColor.navySoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .padding(14)
        .padding(.leading, 2)
        .background(QiheColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(risk.riskLevel.foreground)
                .frame(width: 3.5)
        }
        .overlay(alignment: .topTrailing) {
            Text(risk.riskLevel.label)
                .font(QiheFont.title(size: 10))
                .foregroundStyle(risk.riskLevel.foreground)
                .padding(.horizontal, 6)
                .frame(height: 25)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(risk.riskLevel.foreground, lineWidth: 1.5)
                )
                .rotationEffect(.degrees(4))
                .padding(12)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(QiheColor.line, lineWidth: 1)
        )
    }
}

struct SubjectFactsPanel: View {
    let result: ReviewResult

    var body: some View {
        let facts = result.parties?.subjectFacts ?? []
        let shouldShowEmpty = facts.isEmpty || (result.parties?.hasIncompleteCoreSubjectInfo ?? true)

        VStack(alignment: .leading, spacing: 12) {
            if shouldShowEmpty {
                EmptySubjectBox()
            }

            if !facts.isEmpty {
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
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(QiheColor.line, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

struct EmptySubjectBox: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("空")
                .font(QiheFont.title(size: 20))
                .foregroundStyle(QiheColor.lineStrong)
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(QiheColor.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                )
                .rotationEffect(.degrees(-5))

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
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
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
