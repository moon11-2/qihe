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

struct RiskCard: View {
    let risk: RiskItem

    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(risk.clause?.nilIfBlank ?? "未命名条款")
                            .font(QiheFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)

                        if let basis = risk.basis?.nilIfBlank {
                            Text(basis)
                                .font(QiheFont.caption())
                                .foregroundStyle(QiheColor.muted)
                        }
                    }

                    Spacer()

                    QiheStatusPill(
                        text: risk.riskLevel.label,
                        color: risk.riskLevel.foreground,
                        background: risk.riskLevel.background
                    )
                }

                if let text = risk.originalText?.nilIfBlank {
                    Text(text)
                        .font(QiheFont.body(size: 14))
                        .foregroundStyle(QiheColor.inkSoft)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(QiheColor.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                if let riskText = risk.risk?.nilIfBlank {
                    LabeledText(label: "风险", text: riskText)
                }

                if let suggestion = risk.suggestion?.nilIfBlank {
                    LabeledText(label: "建议", text: suggestion)
                }
            }
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
