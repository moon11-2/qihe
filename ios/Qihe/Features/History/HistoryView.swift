import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var isClearConfirmationPresented = false
    @State private var selectedFilter: HistoryFilter = .all

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                QiheColor.pageBackgroundGradient.ignoresSafeArea()

                Circle()
                    .fill(QiheColor.brandLight.opacity(0.12))
                    .frame(width: 210, height: 210)
                    .blur(radius: 8)
                    .offset(x: 74, y: -94)
                    .accessibilityHidden(true)

                ScrollView {
                    VStack(spacing: 14) {
                        historyHeader

                        if !historyStore.records.isEmpty {
                            filterPicker
                        }

                        if historyStore.records.isEmpty {
                            historyEmptyState(
                                title: "暂无历史记录",
                                detail: "审查、生成或过程对话完成后，会在这里留下可继续打开的本地记录。"
                            )
                        } else if filteredRecords.isEmpty {
                            historyEmptyState(
                                title: "暂无\(selectedFilter.title)记录",
                                detail: "切换到全部，或完成新的\(selectedFilter.title)后再回来查看。"
                            )
                        } else {
                            LazyVStack(spacing: 11) {
                                ForEach(filteredRecords) { record in
                                    HistoryRecordRow(record: record) {
                                        appState.openHistoryRecord(record)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, QiheLayout.rootTabBottomInset)
                }
            }
            .confirmationDialog(
                "清空全部历史？",
                isPresented: $isClearConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("清空全部历史", role: .destructive) {
                    historyStore.clear()
                }

                Button("取消", role: .cancel) {}
            } message: {
                Text("本地保存的历史记录将被删除，此操作无法撤销。")
            }
        }
    }

    private var filteredRecords: [HistoryRecord] {
        historyStore.records.filter { selectedFilter.includes($0) }
    }

    private var historyHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("历史")
                    .font(QiheFont.body(size: 22, weight: .bold))
                    .foregroundStyle(QiheColor.ink)

                Text(historyStore.records.isEmpty ? "本地记录" : "共 \(historyStore.records.count) 条本地记录")
                    .font(QiheFont.caption(size: 12))
                    .foregroundStyle(QiheColor.muted)
            }

            Spacer()

            Button {
                isClearConfirmationPresented = true
            } label: {
                Label("清空", systemImage: "trash")
                    .font(QiheFont.caption(size: 13, weight: .semibold))
                    .foregroundStyle(historyStore.records.isEmpty ? QiheColor.muted : QiheColor.riskRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(QiheColor.glassFill.opacity(historyStore.records.isEmpty ? 0.64 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(QiheColor.glassStroke, lineWidth: 1)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .shadow(color: historyStore.records.isEmpty ? .clear : QiheColor.shadowNavySoft, radius: 10, x: 0, y: 3)
            .disabled(historyStore.records.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }

    private var filterPicker: some View {
        HStack(spacing: 4) {
            ForEach(HistoryFilter.allCases) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(QiheFont.caption(size: 13, weight: selectedFilter == filter ? .semibold : .medium))
                        .foregroundStyle(selectedFilter == filter ? QiheColor.brandBlue : QiheColor.muted)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if selectedFilter == filter {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(QiheColor.neutral0)
                                    .shadow(color: QiheColor.shadowNavySoft, radius: 5, x: 0, y: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(QiheColor.neutral100.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(QiheColor.glassStroke, lineWidth: 1)
        )
        .accessibilityLabel("历史筛选")
    }

    private func historyEmptyState(title: String, detail: String) -> some View {
        EmptyStateView(title: title, detail: detail)
            .padding(.horizontal, 16)
            .background(QiheColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(QiheColor.glassStroke, lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 10, x: 0, y: 3)
    }
}

private enum HistoryFilter: String, CaseIterable, Identifiable {
    case all
    case review
    case generate
    case chat

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .all:
            return "全部"
        case .review:
            return "审查"
        case .generate:
            return "生成"
        case .chat:
            return "对话"
        }
    }

    func includes(_ record: HistoryRecord) -> Bool {
        switch self {
        case .all:
            return true
        case .review:
            return record.type == .review
        case .generate:
            return record.type == .generate
        case .chat:
            return record.type == .chat
        }
    }
}

private struct HistoryRecordRow: View {
    let record: HistoryRecord
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: typeIcon)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(typeColor)
                    .frame(width: 44, height: 44)
                    .background(typeBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title.nilIfBlank ?? "未命名记录")
                        .font(QiheFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(detailText)
                        .font(QiheFont.caption(size: 12))
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                Spacer(minLength: 6)

                Text(statusText)
                    .font(QiheFont.caption(size: 12, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 9)
                    .frame(height: 26)
                    .background(statusBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .padding(14)
            .background(QiheColor.glassFill)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(QiheColor.glassStroke, lineWidth: 1)
            )
            .shadow(color: QiheColor.shadowNavySoft, radius: 8, x: 0, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(record.type.title)，\(record.title.nilIfBlank ?? "未命名记录")，\(statusText)"
        )
        .accessibilityHint("打开这条历史记录")
    }

    private var detailText: String {
        let time = Self.displayTime(for: record.updatedAt)
        guard let subtitle = record.subtitle.nilIfBlank else {
            return time
        }
        return "\(subtitle) · \(time)"
    }

    private var statusText: String {
        switch record.type {
        case .chat:
            return "对话"
        case .generate:
            return "拟定"
        case .review:
            guard let result = record.reviewPayload?.result else {
                return "审查"
            }
            let count = result.displayedRiskCount
            return count > 0 ? "\(count) 处风险" : "已通过"
        }
    }

    private var statusColor: Color {
        guard record.type == .review else {
            return QiheColor.brandBlue
        }
        guard let result = record.reviewPayload?.result else {
            return QiheColor.riskOrange
        }
        guard result.displayedRiskCount > 0 else {
            return QiheColor.safeGreen
        }
        return result.riskLevel == .high ? QiheColor.riskRed : QiheColor.riskOrange
    }

    private var statusBackground: Color {
        guard record.type == .review else {
            return QiheColor.infoBlueSoft
        }
        guard let result = record.reviewPayload?.result else {
            return QiheColor.riskOrangeSoft
        }
        guard result.displayedRiskCount > 0 else {
            return QiheColor.safeGreenSoft
        }
        return result.riskLevel == .high ? QiheColor.riskRedSoft : QiheColor.riskOrangeSoft
    }

    private var typeColor: Color {
        switch record.type {
        case .chat:
            return QiheColor.infoBlue
        case .review:
            return QiheColor.riskOrange
        case .generate:
            return QiheColor.safeGreen
        }
    }

    private var typeBackground: Color {
        switch record.type {
        case .chat:
            return QiheColor.infoBlueSoft
        case .review:
            return QiheColor.riskOrangeSoft
        case .generate:
            return QiheColor.safeGreenSoft
        }
    }

    private var typeIcon: String {
        switch record.type {
        case .chat:
            return "bubble.left.and.text.bubble.right"
        case .review:
            return "doc.text.magnifyingglass"
        case .generate:
            return "doc.text"
        }
    }

    private static func displayTime(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "今天 \(clockFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "昨天 \(clockFormatter.string(from: date))"
        }
        return dateFormatter.string(from: date)
    }

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter
    }()
}
