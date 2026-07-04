import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @State private var isClearConfirmationPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if historyStore.records.isEmpty {
                        PaperCard {
                            EmptyStateView(
                                title: "暂无历史记录",
                                detail: "审查、生成或过程对话完成后，会在这里留下可继续打开的本地记录。"
                            )
                        }
                    } else {
                        ForEach(historyStore.records) { record in
                            HistoryRecordRow(record: record) {
                                appState.openHistoryRecord(record)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .background(QiheColor.paper.ignoresSafeArea())
            .navigationTitle("历史对话")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("清空") {
                        isClearConfirmationPresented = true
                    }
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(historyStore.records.isEmpty ? QiheColor.muted : QiheColor.seal)
                    .disabled(historyStore.records.isEmpty)
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
