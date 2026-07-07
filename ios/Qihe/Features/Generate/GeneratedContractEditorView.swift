import SwiftUI

// MARK: - GeneratedContractEditorView

/// 生成合同编辑器：按段落和占位符展示可编辑的生成结果
struct GeneratedContractEditorView: View {
    /// 合同草稿全文
    let draft: String
    /// 占位符已填写的值（key: 占位符名称, value: 填写的内容）
    @Binding var fieldValues: [String: String]
    /// 被用户编辑过的段落 ID 集合
    @Binding var editedParagraphIds: Set<String>

    /// 解析后的段落数组
    @State private var segments: [DocumentSegment] = []

    /// 当前选中的段落（用于编辑）
    @State private var selectedSegment: DocumentSegment?

    /// 占位符编辑弹窗
    @State private var showPlaceholderSheet = false
    /// 普通段落编辑弹窗
    @State private var showParagraphSheet = false

    /// 定位目标段落 ID（外部设置后自动滚动）
    @Binding var scrollToSegmentId: String?

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(segments) { segment in
                        segmentView(for: segment)
                            .id(segment.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: scrollToSegmentId) { _, targetId in
                guard let targetId, !targetId.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    scrollProxy.scrollTo(targetId, anchor: .center)
                }
                // 闪烁高亮后清除
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToSegmentId = nil
                }
            }
        }
        .onAppear {
            segments = DraftSegmentParser.parse(draft)
        }
        .onChange(of: draft) { _, newDraft in
            segments = DraftSegmentParser.parse(newDraft)
        }
        // 占位符编辑弹窗
        .sheet(isPresented: $showPlaceholderSheet) {
            if let segment = selectedSegment, let name = segment.placeholderName {
                PlaceholderEditSheet(
                    placeholderName: name,
                    currentValue: fieldValues[name] ?? "",
                    onSave: { newValue in
                        applyPlaceholderEdit(segment: segment, name: name, value: newValue)
                    },
                    onClear: {
                        applyPlaceholderClear(segment: segment, name: name)
                    }
                )
            }
        }
        // 普通段落编辑弹窗
        .sheet(isPresented: $showParagraphSheet) {
            if let segment = selectedSegment {
                SegmentEditSheet(
                    segment: segment,
                    onSave: { newText in
                        applyParagraphEdit(segment: segment, newText: newText)
                    }
                )
            }
        }
    }

    // MARK: - Segment Rendering

    @ViewBuilder
    private func segmentView(for segment: DocumentSegment) -> some View {
        switch segment.kind {
        case .placeholder(let name):
            placeholderTokenView(segment: segment, name: name)
        case .paragraph:
            paragraphView(segment: segment)
        }
    }

    /// 占位符 token 视图
    private func placeholderTokenView(segment: DocumentSegment, name: String) -> some View {
        let filledValue = fieldValues[name]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let isFilled = (filledValue != nil && !filledValue!.isEmpty)

        return Button {
            selectedSegment = segment
            showPlaceholderSheet = true
        } label: {
            Group {
                if isFilled, let value = filledValue {
                    Text(value)
                        .font(QiheFont.document(size: 13))
                        .foregroundStyle(QiheColor.pine)
                } else {
                    Text(segment.text)
                        .font(QiheFont.document(size: 13))
                        .foregroundStyle(QiheColor.amber)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isFilled ? QiheColor.pineSoft : QiheColor.amberSoft)
            )
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }

    /// 普通段落视图
    private func paragraphView(segment: DocumentSegment) -> some View {
        let isEdited = editedParagraphIds.contains(segment.id)
            || segment.revisionState == .confirmed
            || segment.revisionState == .draft

        return Button {
            selectedSegment = segment
            showParagraphSheet = true
        } label: {
            Text(segment.text)
                .font(QiheFont.document(size: 13))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(7)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .background(
            isEdited
                ? QiheColor.pineSoft.opacity(0.3)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if isEdited {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(QiheColor.pine)
                    .frame(width: 3)
                    .padding(.vertical, 2)
            }
        }
        .overlay(
            Rectangle()
                .fill(QiheColor.line.opacity(0.5))
                .frame(height: 1)
                .padding(.horizontal, 4),
            alignment: .bottom
        )
    }

    // MARK: - Edit Actions

    /// 应用占位符编辑
    private func applyPlaceholderEdit(segment: DocumentSegment, name: String, value: String) {
        fieldValues[name] = value

        // 更新段落修改状态
        if let idx = segments.firstIndex(where: { $0.id == segment.id }) {
            var updated = segments[idx]
            updated.text = value
            updated.revisionState = .confirmed
            segments[idx] = updated
        }
    }

    /// 清空占位符（恢复待补充状态）
    private func applyPlaceholderClear(segment: DocumentSegment, name: String) {
        fieldValues.removeValue(forKey: name)

        if let idx = segments.firstIndex(where: { $0.id == segment.id }) {
            var updated = segments[idx]
            updated.text = updated.originalText
            updated.revisionState = .original
            segments[idx] = updated
        }
    }

    /// 应用普通段落编辑
    private func applyParagraphEdit(segment: DocumentSegment, newText: String) {
        if let idx = segments.firstIndex(where: { $0.id == segment.id }) {
            var updated = segments[idx]
            updated.text = newText
            updated.revisionState = .confirmed
            segments[idx] = updated
        }

        if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editedParagraphIds.insert(segment.id)
        }
    }
}

// MARK: - PlaceholderEditSheet

/// 占位符编辑弹窗
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

// MARK: - SegmentEditSheet

/// 普通段落编辑弹窗
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
struct GeneratedContractEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GeneratedContractEditorView(
                draft: """
                甲方：【待补充：甲方名称】
                乙方：【待补充：乙方名称】

                第一条 合同标的
                甲方向乙方采购如下商品：具体规格、数量、单价详见附件一。

                第二条 付款方式
                甲方应在收到货物后【待补充：付款期限】内支付全部货款。

                第三条 违约责任
                若任何一方违反本合同约定，应承担相应的违约责任。
                """,
                fieldValues: .constant([:]),
                editedParagraphIds: .constant([]),
                scrollToSegmentId: .constant(nil)
            )
            .padding()
            .background(QiheColor.paper)
        }
    }
}
#endif
