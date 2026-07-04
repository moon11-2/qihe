import SwiftUI

struct SealMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(QiheColor.seal)

            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .stroke(.white.opacity(0.76), lineWidth: max(1, size * 0.035))
                .padding(size * 0.12)

            Text("契")
                .font(QiheFont.seal(size: size * 0.52))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct QihePrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }

                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(QiheFont.body(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .foregroundStyle(.white)
            .background(isDisabled ? QiheColor.muted : QiheColor.navy)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(title)
    }
}

struct QiheSecondaryButton: View {
    let title: String
    var systemImage: String?
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(QiheFont.body(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .foregroundStyle(isDisabled ? QiheColor.muted : QiheColor.navy)
            .background(isDisabled ? QiheColor.line : QiheColor.navySoft)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct PaperCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(QiheColor.line, lineWidth: 1)
            )
    }
}

struct QiheSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QiheFont.title(size: 22))
                .foregroundStyle(QiheColor.ink)

            if let subtitle {
                Text(subtitle)
                    .font(QiheFont.body(size: 13))
                    .foregroundStyle(QiheColor.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QiheStatusPill: View {
    let text: String
    var color: Color = QiheColor.navy
    var background: Color = QiheColor.navySoft

    var body: some View {
        Text(text)
            .font(QiheFont.caption(size: 12, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(background)
            .clipShape(Capsule())
    }
}

struct QiheIconCircleButton: View {
    let systemImage: String
    let accessibilityLabel: String
    var size: CGFloat = 34
    var isPrimary = false
    var isLoading = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(isPrimary ? .white : QiheColor.navy)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: max(14, size * 0.45), weight: .semibold))
                }
            }
            .frame(width: size, height: size)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: isPrimary ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
    }

    private var foreground: Color {
        if isDisabled {
            return QiheColor.muted
        }
        return isPrimary ? .white : QiheColor.inkSoft
    }

    private var background: Color {
        if isDisabled {
            return QiheColor.line
        }
        return isPrimary ? QiheColor.navy : QiheColor.card
    }

    private var borderColor: Color {
        isDisabled ? QiheColor.line : QiheColor.lineStrong
    }
}

struct HomeEntryCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PaperCard {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(QiheColor.navy)
                        .frame(width: 44, height: 44)
                        .background(QiheColor.navySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(QiheFont.body(size: 17, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)

                        Text(subtitle)
                            .font(QiheFont.body(size: 13))
                            .foregroundStyle(QiheColor.muted)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(QiheColor.lineStrong)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct AttachmentRow: View {
    let title: String
    var detail: String?
    var actionTitle: String
    var systemImage: String = "doc.badge.plus"
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        PaperCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(QiheColor.navy)
                    .frame(width: 36, height: 36)
                    .background(QiheColor.navySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(QiheFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(1)

                    if let detail {
                        Text(detail)
                            .font(QiheFont.caption())
                            .foregroundStyle(QiheColor.muted)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button(actionTitle, action: action)
                    .font(QiheFont.caption(size: 12, weight: .semibold))
                    .foregroundStyle(isDisabled ? QiheColor.muted : QiheColor.navy)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(isDisabled ? QiheColor.line : QiheColor.navySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(isDisabled)
            }
        }
    }
}

struct ProcessNode: View {
    let title: String
    let detail: String
    var isActive = false
    var isDone = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isDone ? QiheColor.pine : (isActive ? QiheColor.seal : QiheColor.lineStrong))
                    .frame(width: 22, height: 22)

                Image(systemName: isDone ? "checkmark" : "circle.fill")
                    .font(.system(size: isDone ? 10 : 6, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(QiheColor.ink)

                Text(detail)
                    .font(QiheFont.caption())
                    .foregroundStyle(QiheColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ResultStatItem: Identifiable, Hashable {
    let label: String
    let value: String
    var color: Color = QiheColor.ink

    var id: String {
        label
    }
}

struct ResultStatStrip: View {
    let items: [ResultStatItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                VStack(spacing: 5) {
                    Text(item.value)
                        .font(QiheFont.title(size: 22))
                        .foregroundStyle(item.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(item.label)
                        .font(QiheFont.caption(size: 11, weight: .medium))
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)

                if item.id != items.last?.id {
                    Rectangle()
                        .fill(QiheColor.lineStrong)
                        .frame(width: 1, height: 34)
                        .opacity(0.75)
                }
            }
        }
        .background(QiheColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(QiheColor.lineStrong, lineWidth: 1)
        )
    }
}

struct RiskGradeStamp: View {
    let level: RiskLevel

    var body: some View {
        VStack(spacing: 3) {
            Text(level.gradeMark)
                .font(QiheFont.title(size: 22))
                .lineLimit(1)

            Text(level.label)
                .font(QiheFont.caption(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(level.foreground)
        .frame(width: 60, height: 60)
        .background(QiheColor.card.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(level.foreground, lineWidth: 2)
        )
        .rotationEffect(.degrees(7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("风险等级 \(level.label)")
    }
}

struct RiskCard: View {
    let risk: RiskItem

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(risk.displayTitle)
                            .font(QiheFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)
                    }

                    Spacer()

                    QiheStatusPill(
                        text: risk.riskLevel.label,
                        color: risk.riskLevel.foreground,
                        background: risk.riskLevel.background
                    )
                }

                LabeledText(label: "涉及条款", text: risk.clause?.nilIfBlank ?? "未标注")

                if let analysis = risk.displayAnalysis {
                    LabeledText(label: "风险分析", text: analysis)
                }

                if let suggestion = risk.displaySuggestion {
                    LabeledText(label: "修订建议", text: suggestion)
                }

                if let replacement = risk.suggestedReplacement?.nilIfBlank {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("建议替换文本")
                            .font(QiheFont.caption(size: 12, weight: .semibold))
                            .foregroundStyle(QiheColor.seal)

                        Text(replacement)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(QiheColor.sealSoft.opacity(0.46))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(QiheColor.seal.opacity(0.24), lineWidth: 1)
                    )
                }

                if let legalBasis = risk.displayLegalBasis {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "building.columns")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(QiheColor.navy)
                            .frame(width: 18)

                        LabeledText(label: "法条依据", text: legalBasis)
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(risk.riskLevel.foreground)
                .frame(width: 3)
                .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                .padding(.vertical, 1)
        }
    }
}

struct SubjectEmptyNotice: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("空")
                .font(QiheFont.title(size: 20))
                .foregroundStyle(QiheColor.lineStrong)
                .frame(width: 46, height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(QiheColor.lineStrong, style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                )
                .rotationEffect(.degrees(-5))

            Text("未识别到乙方、金额或期限等信息，请确认合同文本是否完整。")
                .font(QiheFont.body(size: 13))
                .foregroundStyle(QiheColor.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 18)
        .background(QiheColor.card.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(QiheColor.lineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        )
    }
}

struct SubjectFactGrid: View {
    let facts: [ContractSubjectFact]

    private let columns = [
        GridItem(.adaptive(minimum: 132), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(facts) { fact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fact.label)
                        .font(QiheFont.caption(size: 12, weight: .semibold))
                        .foregroundStyle(QiheColor.muted)

                    Text(fact.value)
                        .font(QiheFont.body(size: 14, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(3)
                        .minimumScaleFactor(0.82)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(QiheColor.card)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(QiheColor.line, lineWidth: 1)
                )
            }
        }
    }
}

struct ContractDraftSheet: View {
    let title: String
    var subtitle: String?
    let draft: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 5) {
                Text(title)
                    .font(QiheFont.title(size: 20))
                    .foregroundStyle(QiheColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                if let subtitle {
                    Text(subtitle)
                        .font(QiheFont.caption(size: 10, weight: .medium))
                        .foregroundStyle(QiheColor.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }

            Text(draft.nilIfBlank ?? "暂无合同草案。")
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 46)
        .background(QiheColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(QiheColor.lineStrong, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(QiheColor.line, lineWidth: 1)
                .padding(6)
        )
        .overlay(alignment: .bottomTrailing) {
            Text("待签\n用印")
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.seal.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .frame(width: 54, height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(QiheColor.seal.opacity(0.5), lineWidth: 2)
                )
                .rotationEffect(.degrees(-7))
                .padding(.trailing, 16)
                .padding(.bottom, 10)
        }
    }
}

struct QiheFormInput: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.navy)

            TextField("填写\(title)", text: $text, axis: .vertical)
                .font(QiheFont.body(size: 14))
                .lineLimit(1...3)
                .padding(.horizontal, 11)
                .padding(.vertical, 10)
                .background(QiheColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(QiheColor.line, lineWidth: 1)
                )
        }
    }
}

struct LabeledText: View {
    let label: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(QiheFont.caption(size: 12, weight: .semibold))
                .foregroundStyle(QiheColor.navy)

            Text(text)
                .font(QiheFont.body(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyStateView: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 10) {
            SealMark(size: 42)
                .opacity(0.82)

            Text(title)
                .font(QiheFont.body(size: 16, weight: .semibold))
                .foregroundStyle(QiheColor.ink)

            Text(detail)
                .font(QiheFont.body(size: 13))
                .foregroundStyle(QiheColor.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

struct ErrorBanner: View {
    let message: String
    var retryTitle: String?
    var retry: (() -> Void)?

    var body: some View {
        PaperCard(padding: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(QiheColor.seal)

                Text(message)
                    .font(QiheFont.body(size: 13))
                    .foregroundStyle(QiheColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if let retryTitle, let retry {
                    Button(retryTitle, action: retry)
                        .font(QiheFont.caption(size: 12, weight: .semibold))
                        .foregroundStyle(QiheColor.navy)
                }
            }
        }
    }
}

extension RiskLevel {
    var gradeMark: String {
        switch self {
        case .high:
            return "D"
        case .medium:
            return "C"
        case .low:
            return "A"
        case .pending:
            return "待"
        case .unknown:
            return "?"
        }
    }

    var foreground: Color {
        switch self {
        case .high:
            return QiheColor.seal
        case .medium:
            return QiheColor.amber
        case .low:
            return QiheColor.pine
        case .pending, .unknown:
            return QiheColor.navy
        }
    }

    var background: Color {
        switch self {
        case .high:
            return QiheColor.sealSoft
        case .medium:
            return QiheColor.amberSoft
        case .low:
            return QiheColor.pineSoft
        case .pending, .unknown:
            return QiheColor.navySoft
        }
    }
}

extension View {
    @ViewBuilder
    func qiheInlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func qiheHistorySheetPresentation() -> some View {
        #if os(iOS)
        presentationDetents([.medium, .large])
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    static var qiheTopTrailing: ToolbarItemPlacement {
        #if os(iOS)
        return .topBarTrailing
        #else
        return .automatic
        #endif
    }
}
