import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var input = ""

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button {
                        appState.isHistoryPresented = true
                    } label: {
                        Image(systemName: "sidebar.left")
                    }

                    Spacer()

                    Button {
                        appState.path.append(.chat(localRecordId: nil))
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
                .foregroundStyle(QiheColor.ink)

                Spacer(minLength: 24)

                SealMark(size: 64)
                Text("契合")
                    .font(QiheFont.title(size: 30))
                    .tracking(8)
                Text("AI 合同审查与生成助手")
                    .font(.system(size: 13))
                    .foregroundStyle(QiheColor.muted)

                PaperCard {
                    TextEditor(text: $input)
                        .frame(minHeight: 92)
                        .scrollContentBackground(.hidden)
                }

                HStack(spacing: 12) {
                    Button("合同审查") {
                        appState.path.append(.review(prefill: input.isEmpty ? nil : input))
                    }
                    .buttonStyle(.bordered)

                    Button("合同生成") {
                        appState.path.append(.generate(prefill: input.isEmpty ? nil : input))
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

