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

