import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(historyStore.records) { record in
                Button {
                    open(record)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label(record.title, systemImage: iconName(for: record.type))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(QiheColor.ink)
                            Spacer()
                            Text(record.createdAt, style: .date)
                                .font(.system(size: 12))
                                .foregroundStyle(QiheColor.muted)
                        }
                        if !record.textPreview.isEmpty {
                            Text(record.textPreview)
                                .font(.system(size: 13))
                                .foregroundStyle(QiheColor.inkSoft)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .overlay {
                if historyStore.records.isEmpty {
                    Text("暂无本地历史")
                        .foregroundStyle(QiheColor.muted)
                }
            }
            .navigationTitle("历史对话")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("清空") {
                        historyStore.clear()
                    }
                    .disabled(historyStore.records.isEmpty)
                }
            }
        }
    }

    private func open(_ record: HistoryRecord) {
        dismiss()
        appState.isHistoryPresented = false
        switch record.type {
        case .chat:
            appState.path.append(.chat(localRecordId: record.id))
        case .review:
            appState.path.append(.reviewResult(recordId: record.id))
        case .generate:
            appState.path.append(.generateResult(recordId: record.id))
        }
    }

    private func iconName(for type: HistoryRecord.RecordType) -> String {
        switch type {
        case .chat:
            return "bubble.left.and.bubble.right"
        case .review:
            return "doc.text.magnifyingglass"
        case .generate:
            return "doc.badge.plus"
        }
    }
}
