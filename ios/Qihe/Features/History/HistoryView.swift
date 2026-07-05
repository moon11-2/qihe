import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var isClearConfirmationPresented = false
    @State private var selectedFilter: HistoryFilter = .all

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    historyHeader

                    if !historyStore.records.isEmpty {
                        filterPicker
                    }

                    if historyStore.records.isEmpty {
                        PaperCard {
                            EmptyStateView(
                                title: "暂无历史记录",
                                detail: "审查、生成或过程对话完成后，会在这里留下可继续打开的本地记录。"
                            )
                        }
                    } else if filteredRecords.isEmpty {
                        PaperCard {
                            EmptyStateView(
                                title: "暂无\(selectedFilter.title)记录",
                                detail: "切换到全部，或完成新的\(selectedFilter.title)后再回来查看。"
                            )
                        }
                    } else {
                        ForEach(filteredRecords) { record in
                            HistoryRecordRow(record: record) {
                                appState.openHistoryRecord(record)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, QiheLayout.rootTabBottomInset)
            }
            .background(QiheColor.paper.ignoresSafeArea())
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
        HStack(alignment: .center) {
            Text("历史")
                .font(QiheFont.title(size: 34))
                .foregroundStyle(QiheColor.ink)
                .lineLimit(1)

            Spacer()

            Button {
                isClearConfirmationPresented = true
            } label: {
                Text("清空")
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(historyStore.records.isEmpty ? QiheColor.muted : QiheColor.seal)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
                    .frame(height: 38)
                    .background(QiheColor.card.opacity(historyStore.records.isEmpty ? 0.55 : 1))
                    .clipShape(Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .shadow(color: .black.opacity(historyStore.records.isEmpty ? 0 : 0.04), radius: 12, x: 0, y: 6)
            .disabled(historyStore.records.isEmpty)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var filterPicker: some View {
        Picker("历史类型", selection: $selectedFilter) {
            ForEach(HistoryFilter.allCases) { filter in
                Text(filter.title).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("历史筛选")
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
            PaperCard(padding: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        QiheStatusPill(
                            text: record.type.title,
                            color: typeColor,
                            background: typeBackground
                        )

                        Spacer(minLength: 8)

                        Text(Self.updatedAtFormatter.localizedString(for: record.updatedAt, relativeTo: Date()))
                            .font(QiheFont.caption(size: 12))
                            .foregroundStyle(QiheColor.muted)
                            .lineLimit(1)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.title.nilIfBlank ?? "未命名记录")
                            .font(QiheFont.body(size: 16, weight: .semibold))
                            .foregroundStyle(QiheColor.ink)
                            .lineLimit(2)

                        if let subtitle = record.subtitle.nilIfBlank {
                            Text(subtitle)
                                .font(QiheFont.body(size: 13))
                                .foregroundStyle(QiheColor.muted)
                                .lineLimit(1)
                        }
                    }

                    if let preview = record.preview.nilIfBlank {
                        Text(preview)
                            .font(QiheFont.body(size: 14))
                            .foregroundStyle(QiheColor.inkSoft)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(QiheColor.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(record.type.title)，\(record.title.nilIfBlank ?? "未命名记录")")
    }

    private var typeColor: Color {
        switch record.type {
        case .chat:
            return QiheColor.navy
        case .review:
            return QiheColor.seal
        case .generate:
            return QiheColor.pine
        }
    }

    private var typeBackground: Color {
        switch record.type {
        case .chat:
            return QiheColor.navySoft
        case .review:
            return QiheColor.sealSoft
        case .generate:
            return QiheColor.pineSoft
        }
    }

    private static let updatedAtFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.unitsStyle = .short
        return formatter
    }()
}
