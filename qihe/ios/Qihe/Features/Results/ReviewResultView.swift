import SwiftUI

struct ReviewResultView: View {
    let recordId: UUID

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                Text("合同审查报告")
                    .font(QiheFont.title(size: 24))

                PaperCard {
                    Text("风险列表、主体信息和原文页将在 M2 接入。")
                        .foregroundStyle(QiheColor.muted)
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

