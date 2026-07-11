import PDFKit
import SwiftUI
import zlib

struct SealMark: View {
    let size: CGFloat

    var body: some View {
        QiheLogoMark(size: size)
            .frame(width: size, height: size)
    }
}

struct QiheLogoMark: View {
    let size: CGFloat

    var body: some View {
        Image("QiheLogo")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 契合产品内的 AI 合同助手“小契”。
///
/// 这是没有正式角色素材时的可替换占位组件。它使用抽象对话符号，
/// 与 `QiheLogoMark` 的品牌职责保持分离，也不使用盾牌图形。
struct QiheAssistantAvatar: View {
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [QiheColor.brandLight, QiheColor.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(QiheColor.neutral0.opacity(0.96))
                .frame(width: size * 0.58, height: size * 0.43)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: size * 0.07) {
                        Capsule(style: .continuous)
                            .fill(QiheColor.brandBlue)
                            .frame(width: size * 0.25, height: max(2, size * 0.055))

                        Capsule(style: .continuous)
                            .fill(QiheColor.brandFrost)
                            .frame(width: size * 0.34, height: max(2, size * 0.055))
                    }
                    .padding(.leading, size * 0.12)
                }
                .overlay(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: size * 0.03, style: .continuous)
                        .fill(QiheColor.neutral0.opacity(0.96))
                        .frame(width: size * 0.13, height: size * 0.13)
                        .rotationEffect(.degrees(42))
                        .offset(x: size * 0.09, y: size * 0.045)
                }
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.31, style: .continuous)
                .stroke(QiheColor.neutral0.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: QiheColor.shadowBlue.opacity(0.55), radius: size * 0.18, x: 0, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

struct QiheBrandLockup: View {
    var markSize: CGFloat = 36
    var titleSize: CGFloat = 22
    var subtitle = "CONTRACT AI"

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            QiheLogoMark(size: markSize)

            VStack(alignment: .leading, spacing: 2) {
                Text("契合")
                    .font(QiheFont.h2(size: titleSize, weight: .bold))
                    .foregroundStyle(QiheColor.ink)
                    .lineLimit(1)

                Text(subtitle)
                    .font(QiheFont.micro(size: max(8, titleSize * 0.34), weight: .semibold))
                    .foregroundStyle(QiheColor.muted)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("契合")
    }
}

struct QiheSloganLockup: View {
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 8 : 10) {
            sloganMark

            VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                Text("您最专业的")
                    .font(QiheFont.caption(size: compact ? 10.5 : 11.5, weight: .medium))
                    .foregroundStyle(QiheColor.inkSoft)
                    .lineLimit(1)

                Text("合同伙伴")
                    .font(QiheFont.body(size: compact ? 13 : 14, weight: .semibold))
                    .foregroundStyle(QiheColor.navy)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: true, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("您最专业的合同伙伴")
    }

    private var sloganMark: some View {
        ZStack(alignment: .center) {
            QiheLogoMark(size: compact ? 22 : 26)
        }
        .frame(width: compact ? 22 : 26, height: compact ? 31 : 35)
        .accessibilityHidden(true)
    }
}

struct BlankSealMark: View {
    var size: CGFloat = 46

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(QiheColor.infoBlueSoft)

            QiheLogoMark(size: size * 0.46)
                .opacity(0.72)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .strokeBorder(QiheColor.glassStroke, style: StrokeStyle(lineWidth: max(1, size * 0.030), dash: [5, 4]))
        )
    }
}

struct QihePrimaryButton: View {
    let title: String
    var systemImage: String?
    var isLoading = false
    var isDisabled = false
    let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 48

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
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(QiheFont.body(size: 16, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .foregroundStyle(.white)
            .background {
                if isDisabled {
                    RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous)
                        .fill(QiheColor.neutral300)
                } else {
                    RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous)
                        .fill(QiheColor.primaryGradient)
                }
            }
            .shadow(color: isDisabled ? .clear : QiheColor.shadowBlue, radius: 24, x: 0, y: 8)
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
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 44

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(QiheFont.body(size: 15, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .frame(minHeight: minHeight)
            .foregroundStyle(isDisabled ? QiheColor.muted : QiheColor.brandBlue)
            .background {
                RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous)
                    .fill(isDisabled ? QiheColor.neutral100 : QiheColor.glassFill)
            }
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous)
                    .stroke(isDisabled ? QiheColor.line : QiheColor.glassStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}

struct PaperCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                    .stroke(QiheColor.glassStroke, lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 8, x: 0, y: 2)
    }
}

struct QiheGlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = QiheRadius.card
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(QiheColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(QiheColor.glassStroke, lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 10, x: 0, y: 3)
    }
}

struct QiheSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(QiheFont.h1(size: 22))
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
    @ScaledMetric(relativeTo: .caption) private var minHeight: CGFloat = 24

    var body: some View {
        Text(text)
            .font(QiheFont.micro(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(minHeight: minHeight)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))
    }
}

struct QiheRiskBadge: View {
    let level: RiskLevel
    var text: String?

    var body: some View {
        QiheStatusPill(
            text: text ?? level.label,
            color: level.foreground,
            background: level.background
        )
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
                        .tint(.white)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: max(14, size * 0.45), weight: .semibold))
                }
            }
            .frame(width: size, height: size)
            .foregroundStyle(foreground)
            .background {
                if isLoading {
                    Circle()
                        .fill(QiheColor.primaryGradient)
                } else if isDisabled {
                    Circle()
                        .fill(QiheColor.line)
                } else if isPrimary {
                    Circle()
                        .fill(QiheColor.primaryGradient)
                } else {
                    Circle()
                        .fill(QiheColor.card)
                }
            }
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(borderColor, lineWidth: isLoading || isPrimary ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled || isLoading)
        .accessibilityLabel(accessibilityLabel)
    }

    private var foreground: Color {
        if isLoading {
            return .white
        }
        if isDisabled {
            return QiheColor.muted
        }
        return isPrimary ? .white : QiheColor.inkSoft
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
                        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))

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
        QiheGlassCard(padding: 14) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isDisabled ? QiheColor.neutral300 : QiheColor.brandBlue)
                    .frame(width: 40, height: 40)
                    .background(isDisabled ? QiheColor.neutral100 : QiheColor.infoBlueSoft)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))

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

                Button(action: action) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12, weight: .semibold))

                        Text(actionTitle)
                    }
                    .font(QiheFont.caption(size: 12, weight: .semibold))
                    .foregroundStyle(isDisabled ? QiheColor.muted : QiheColor.brandBlue)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
                    .padding(.horizontal, 11)
                    .frame(minWidth: 50)
                    .frame(height: 32)
                    .background(isDisabled ? QiheColor.neutral100 : QiheColor.infoBlueSoft)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                .strokeBorder(
                    isDisabled ? QiheColor.line : QiheColor.brandFrost,
                    style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                )
        )
    }
}

struct QiheSegmentedOption<SelectionValue: Hashable>: Identifiable {
    let value: SelectionValue
    let title: String
    var systemImage: String?

    var id: SelectionValue {
        value
    }
}

struct QiheSegmentedPicker<SelectionValue: Hashable>: View {
    let options: [QiheSegmentedOption<SelectionValue>]
    @Binding var selection: SelectionValue
    @ScaledMetric(relativeTo: .caption) private var optionMinHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                Button {
                    selection = option.value
                } label: {
                    HStack(spacing: 6) {
                        if let systemImage = option.systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(option.title)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(QiheFont.caption(size: 13, weight: isSelected(option) ? .semibold : .medium))
                    .foregroundStyle(isSelected(option) ? QiheColor.brandBlue : QiheColor.muted)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: optionMinHeight)
                    .background {
                        if isSelected(option) {
                            RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous)
                                .fill(QiheColor.card)
                                .shadow(color: QiheColor.shadowNavySoft, radius: 4, x: 0, y: 1)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(QiheColor.neutral100.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input + 4, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.input + 4, style: .continuous)
                .stroke(QiheColor.glassStroke, lineWidth: 1)
        )
    }

    private func isSelected(_ option: QiheSegmentedOption<SelectionValue>) -> Bool {
        selection == option.value
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
                    .fill(isDone ? QiheColor.pine : (isActive ? QiheColor.navy : QiheColor.lineStrong))
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
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(QiheColor.lineStrong, lineWidth: 1)
        )
    }
}

struct RiskGradeStamp: View {
    let level: RiskLevel

    var body: some View {
        VStack(spacing: 4) {
            Text(level.gradeMark)
                .font(QiheFont.h2(size: 22, weight: .bold))
                .lineLimit(1)

            Text(level.label)
                .font(QiheFont.micro(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(level.foreground)
        .frame(width: 62, height: 58)
        .background(level.background)
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.card, style: .continuous)
                .stroke(level.foreground.opacity(0.35), lineWidth: 1)
        )
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
                            .foregroundStyle(QiheColor.brandBlue)

                        Text(replacement)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(QiheColor.infoBlueSoft)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                            .stroke(QiheColor.brandFrost.opacity(0.72), lineWidth: 1)
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
            BlankSealMark(size: 46)

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
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
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
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
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
                .font(QiheFont.document(size: 13))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 46)
        .background(QiheColor.card)
        .clipShape(RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.md, style: .continuous)
                .stroke(QiheColor.lineStrong, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
                .stroke(QiheColor.line, lineWidth: 1)
                .padding(6)
        )
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 5) {
                QiheLogoMark(size: 16)

                Text("待确认")
                    .font(QiheFont.micro(size: 11, weight: .semibold))
            }
            .foregroundStyle(QiheColor.brandBlue)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(QiheColor.infoBlueSoft)
            .clipShape(RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: QiheRadius.badge, style: .continuous)
                    .stroke(QiheColor.brandFrost, lineWidth: 1)
            )
            .padding(.trailing, 16)
            .padding(.bottom, 12)
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
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: QiheRadius.xs, style: .continuous)
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
            BlankSealMark(size: 42)

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
                    .foregroundStyle(QiheColor.riskRed)

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
            return "未"
        case .unknown:
            return "?"
        }
    }

    var foreground: Color {
        switch self {
        case .high:
            return QiheColor.riskRed
        case .medium:
            return QiheColor.riskOrange
        case .low:
            return QiheColor.safeGreen
        case .pending, .unknown:
            return QiheColor.infoBlue
        }
    }

    var background: Color {
        switch self {
        case .high:
            return QiheColor.riskRedSoft
        case .medium:
            return QiheColor.riskOrangeSoft
        case .low:
            return QiheColor.safeGreenSoft
        case .pending, .unknown:
            return QiheColor.infoBlueSoft
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

/// 只保存当前前台上传会话所需的展示信息，不参与合同请求或本地历史持久化。
@MainActor
enum QiheUploadPresentationCache {
    private static var characterCounts: [String: Int] = [:]

    static func store(characterCount: Int?, for file: UploadedFile) {
        guard let characterCount else {
            return
        }
        characterCounts[file.fileId] = characterCount
    }

    static func characterCount(for file: UploadedFile?) -> Int? {
        guard let file else {
            return nil
        }
        return characterCounts[file.fileId]
    }
}

/// 从用户选中的本地文件计算展示用字符数，避免扩展上传 DTO。
enum QiheLocalDocumentMetrics {
    static func characterCount(at fileURL: URL) -> Int? {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        switch fileURL.pathExtension.lowercased() {
        case "txt":
            return textCharacterCount(at: fileURL)
        case "pdf":
            return PDFDocument(url: fileURL)?.string?.count
        case "docx":
            return docxCharacterCount(at: fileURL)
        default:
            return nil
        }
    }

    private static func textCharacterCount(at fileURL: URL) -> Int? {
        if let text = try? String(contentsOf: fileURL, encoding: .utf8) {
            return text.count
        }

        var encoding = String.Encoding.utf8
        return (try? String(contentsOf: fileURL, usedEncoding: &encoding))?.count
    }

    private static func docxCharacterCount(at fileURL: URL) -> Int? {
        guard let archiveData = try? Data(contentsOf: fileURL),
              let documentXML = zipEntry(named: "word/document.xml", in: archiveData) else {
            return nil
        }

        let parserDelegate = QiheDocxCharacterCounter()
        let parser = XMLParser(data: documentXML)
        parser.delegate = parserDelegate
        return parser.parse() ? parserDelegate.characterCount : nil
    }

    private static func zipEntry(named targetName: String, in archiveData: Data) -> Data? {
        guard let endRecordOffset = zipEndRecordOffset(in: archiveData),
              let entryCount = readUInt16(archiveData, at: endRecordOffset + 10),
              let centralDirectoryOffset = readUInt32(archiveData, at: endRecordOffset + 16) else {
            return nil
        }

        var offset = Int(centralDirectoryOffset)
        for _ in 0..<Int(entryCount) {
            guard readUInt32(archiveData, at: offset) == 0x02014B50,
                  let compressionMethod = readUInt16(archiveData, at: offset + 10),
                  let compressedSize = readUInt32(archiveData, at: offset + 20),
                  let uncompressedSize = readUInt32(archiveData, at: offset + 24),
                  let filenameLength = readUInt16(archiveData, at: offset + 28),
                  let extraLength = readUInt16(archiveData, at: offset + 30),
                  let commentLength = readUInt16(archiveData, at: offset + 32),
                  let localHeaderOffset = readUInt32(archiveData, at: offset + 42) else {
                return nil
            }

            let nameStart = offset + 46
            let nameEnd = nameStart + Int(filenameLength)
            guard nameEnd <= archiveData.count else {
                return nil
            }
            let filename = String(data: archiveData[nameStart..<nameEnd], encoding: .utf8)

            if filename == targetName {
                return extractZipEntry(
                    from: archiveData,
                    localHeaderOffset: Int(localHeaderOffset),
                    compressionMethod: compressionMethod,
                    compressedSize: Int(compressedSize),
                    uncompressedSize: Int(uncompressedSize)
                )
            }

            offset = nameEnd + Int(extraLength) + Int(commentLength)
        }

        return nil
    }

    private static func zipEndRecordOffset(in data: Data) -> Int? {
        guard data.count >= 22 else {
            return nil
        }
        let earliestOffset = max(0, data.count - 65_557)
        for offset in stride(from: data.count - 22, through: earliestOffset, by: -1) {
            if readUInt32(data, at: offset) == 0x06054B50 {
                return offset
            }
        }
        return nil
    }

    private static func extractZipEntry(
        from archiveData: Data,
        localHeaderOffset: Int,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) -> Data? {
        guard readUInt32(archiveData, at: localHeaderOffset) == 0x04034B50,
              let localFilenameLength = readUInt16(archiveData, at: localHeaderOffset + 26),
              let localExtraLength = readUInt16(archiveData, at: localHeaderOffset + 28) else {
            return nil
        }

        let dataStart = localHeaderOffset + 30 + Int(localFilenameLength) + Int(localExtraLength)
        let dataEnd = dataStart + compressedSize
        guard dataStart >= 0, dataEnd <= archiveData.count else {
            return nil
        }
        let compressedData = Data(archiveData[dataStart..<dataEnd])

        switch compressionMethod {
        case 0:
            return compressedData
        case 8:
            return inflateRawDeflate(compressedData, expectedSize: uncompressedSize)
        default:
            return nil
        }
    }

    private static func inflateRawDeflate(_ data: Data, expectedSize: Int) -> Data? {
        guard !data.isEmpty, expectedSize > 0 else {
            return expectedSize == 0 ? Data() : nil
        }

        var stream = z_stream()
        let initializationStatus = inflateInit2_(
            &stream,
            -MAX_WBITS,
            ZLIB_VERSION,
            Int32(MemoryLayout<z_stream>.size)
        )
        guard initializationStatus == Z_OK else {
            return nil
        }
        defer { inflateEnd(&stream) }

        var output = Data(count: expectedSize)
        let status: Int32 = data.withUnsafeBytes { sourceBuffer in
            output.withUnsafeMutableBytes { destinationBuffer in
                guard let source = sourceBuffer.bindMemory(to: Bytef.self).baseAddress,
                      let destination = destinationBuffer.bindMemory(to: Bytef.self).baseAddress else {
                    return Z_DATA_ERROR
                }
                stream.next_in = UnsafeMutablePointer(mutating: source)
                stream.avail_in = uInt(data.count)
                stream.next_out = destination
                stream.avail_out = uInt(expectedSize)
                return inflate(&stream, Z_FINISH)
            }
        }

        guard status == Z_STREAM_END else {
            return nil
        }
        output.removeSubrange(Int(stream.total_out)..<output.count)
        return output
    }

    private static func readUInt16(_ data: Data, at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= data.count else {
            return nil
        }
        return UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
    }

    private static func readUInt32(_ data: Data, at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= data.count else {
            return nil
        }
        return UInt32(data[offset])
            | (UInt32(data[offset + 1]) << 8)
            | (UInt32(data[offset + 2]) << 16)
            | (UInt32(data[offset + 3]) << 24)
    }
}

private final class QiheDocxCharacterCounter: NSObject, XMLParserDelegate {
    private(set) var characterCount = 0
    private var isInsideTextNode = false

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        isInsideTextNode = elementName == "w:t" || elementName.hasSuffix(":t")
        if elementName == "w:tab" || elementName == "w:br" {
            characterCount += 1
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideTextNode else {
            return
        }
        characterCount += string.count
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "w:t" || elementName.hasSuffix(":t") {
            isInsideTextNode = false
        } else if elementName == "w:p" {
            characterCount += 1
        }
    }
}
