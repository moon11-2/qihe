import SwiftUI

struct GenerateInputView: View {
    @State private var text: String

    init(prefill: String?) {
        _text = State(initialValue: prefill ?? "")
    }

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(spacing: 16) {
                Text("合同生成")
                    .font(QiheFont.title(size: 28))

                PaperCard {
                    TextEditor(text: $text)
                        .frame(minHeight: 220)
                        .scrollContentBackground(.hidden)
                }

                Spacer()

                QihePrimaryButton(title: "生成合同") {
                }
            }
            .padding(20)
        }
    }
}

