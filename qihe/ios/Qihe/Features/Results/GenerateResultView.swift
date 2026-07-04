import SwiftUI

struct GenerateResultView: View {
    let recordId: UUID

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(spacing: 16) {
                HStack {
                    SealMark(size: 30)
                    Text("合同草案")
                        .font(QiheFont.title(size: 22))
                    Spacer()
                }

                PaperCard {
                    Text("合同草案、待补充字段和签署前清单将在 M2 接入。")
                        .foregroundStyle(QiheColor.muted)
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

