import SwiftUI

struct HistoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("本地历史将在 M2 接入 SwiftData。")
                    .foregroundStyle(QiheColor.muted)
            }
            .navigationTitle("历史对话")
        }
    }
}

