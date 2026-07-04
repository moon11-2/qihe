import SwiftUI

struct ReviewInputView: View {
    @State private var text: String

    init(prefill: String?) {
        _text = State(initialValue: prefill ?? "")
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("合同审查")
                    .font(QiheFont.title(size: 28))

                PaperCard {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                }

                Button {
                } label: {
                    Label("上传 PDF / Word / TXT", systemImage: "doc.badge.plus")
                }
                .buttonStyle(.bordered)

                Spacer()

                QihePrimaryButton(title: "开始审查") {
                }
            }
            .padding(20)
        }
    }
}

