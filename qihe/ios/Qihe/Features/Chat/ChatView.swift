import SwiftUI

struct ChatView: View {
    @State private var input = ""

    var body: some View {
        VStack {
            ScrollView {
                Text("聊天和审查/生成路由将在 M2 接入。")
                    .foregroundStyle(QiheColor.muted)
                    .padding()
            }

            HStack {
                TextField("请输入问题", text: $input)
                    .textFieldStyle(.roundedBorder)

                Button {
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(QiheColor.navy)
                }
            }
            .padding()
        }
        .navigationTitle("契合")
        .navigationBarTitleDisplayMode(.inline)
    }
}

