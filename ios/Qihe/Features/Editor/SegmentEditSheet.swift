import SwiftUI

// MARK: - SegmentEditSheet

/// 段落编辑弹窗：编辑普通段落文本的界面
struct SegmentEditSheet: View {
    let segment: DocumentSegment
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editText: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("编辑段落")
                    .font(QiheFont.title(size: 18))
                    .foregroundStyle(QiheColor.ink)
                    .padding(.top, 8)

                TextEditor(text: $editText)
                    .font(QiheFont.document(size: 14))
                    .foregroundStyle(QiheColor.ink)
                    .lineSpacing(6)
                    .padding(10)
                    .frame(minHeight: 160)
                    .background(QiheColor.paper)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: QiheRadius.sm, style: .continuous)
                            .stroke(QiheColor.line, lineWidth: 1)
                    )

                HStack {
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
                editText = segment.text
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Preview

#if DEBUG
struct SegmentEditSheet_Previews: PreviewProvider {
    static var previews: some View {
        SegmentEditSheet(
            segment: DocumentSegment(
                kind: .paragraph,
                text: "甲方向乙方采购如下商品：具体规格、数量、单价详见附件一。"
            ),
            onSave: { _ in }
        )
    }
}
#endif
