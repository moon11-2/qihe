import SwiftUI

// MARK: - PlaceholderEditSheet

/// 占位符编辑弹窗：点击占位符后弹出的编辑界面
struct PlaceholderEditSheet: View {
    let placeholderName: String
    let currentValue: String
    let onSave: (String) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editText: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("编辑占位符")
                    .font(QiheFont.title(size: 18))
                    .foregroundStyle(QiheColor.ink)
                    .padding(.top, 8)

                Text("「\(placeholderName)」")
                    .font(QiheFont.caption(size: 13))
                    .foregroundStyle(QiheColor.amber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(QiheColor.amberSoft)
                    )

                TextEditor(text: $editText)
                    .font(QiheFont.body(size: 15))
                    .foregroundStyle(QiheColor.ink)
                    .padding(10)
                    .frame(minHeight: 120)
                    .background(QiheColor.paper)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                            .stroke(QiheColor.line, lineWidth: 1)
                    )

                HStack(spacing: 12) {
                    if !currentValue.isEmpty {
                        Button(role: .destructive) {
                            onClear()
                            dismiss()
                        } label: {
                            Label("清空恢复", systemImage: "arrow.uturn.backward")
                                .font(QiheFont.body(size: 14, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .tint(QiheColor.seal)
                    }

                    Spacer()

                    Button("取消") {
                        dismiss()
                    }
                    .font(QiheFont.body(size: 15, weight: .medium))
                    .foregroundStyle(QiheColor.muted)

                    Button("确认") {
                        onSave(editText)
                        dismiss()
                    }
                    .font(QiheFont.body(size: 15, weight: .semibold))
                    .foregroundStyle(QiheColor.navy)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .onAppear {
                editText = currentValue
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#if DEBUG
struct PlaceholderEditSheet_Previews: PreviewProvider {
    static var previews: some View {
        PlaceholderEditSheet(
            placeholderName: "甲方名称",
            currentValue: "",
            onSave: { _ in },
            onClear: {}
        )
    }
}
#endif
