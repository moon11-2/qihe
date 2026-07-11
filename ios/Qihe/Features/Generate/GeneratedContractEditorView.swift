import SwiftUI

// MARK: - GeneratedContractEditorView

/// 生成合同编辑器：按段落和占位符展示可编辑的生成结果
struct GeneratedContractEditorView: View {
    /// 合同草稿全文（回退用，当 preParsedSegments 为 nil 时前端本地解析）
    let draft: String
    /// 预解析的段落数组（任务三：后端 blocks 优先使用，为 nil 时前端本地分段）
    var preParsedSegments: [DocumentSegment]? = nil
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
    /// 将编辑器当前展示的唯一正文回传给结果页
    let onDraftChange: (String) -> Void

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if segments.isEmpty {
                        Text("暂无合同草案。")
                            .font(QiheFont.document(size: 15))
                            .foregroundStyle(QiheColor.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 16)
                    } else {
                        ForEach(segments) { segment in
                            segmentView(for: segment)
                                .id(segment.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
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
            let initialSegments: [DocumentSegment]
            if let preParsed = preParsedSegments {
                initialSegments = preParsed
            } else {
                initialSegments = DraftSegmentParser.parse(draft)
            }
            replaceSegments(with: initialSegments)
        }
        .onChange(of: draft) { _, newDraft in
            guard preParsedSegments == nil else { return }
            replaceSegments(with: DraftSegmentParser.parse(newDraft))
        }
        // 占位符编辑弹窗
        .sheet(isPresented: $showPlaceholderSheet) {
            if let segment = selectedSegment, let name = segment.placeholderName {
                InlinePlaceholderFillSheet(
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
            HStack(spacing: 4) {
                if isFilled, let value = filledValue {
                    Text(value)
                        .foregroundStyle(QiheColor.safeGreen)
                } else {
                    Text(segment.text)
                        .foregroundStyle(QiheColor.riskOrange)
                }

                Image(systemName: isFilled ? "checkmark.circle.fill" : "square.and.pencil")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(isFilled ? QiheColor.safeGreen : QiheColor.riskOrange)
            }
            .font(QiheFont.contractDocument(size: 15, weight: .medium))
            .lineLimit(2)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isFilled ? QiheColor.safeGreenSoft : QiheColor.riskOrangeSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        isFilled ? QiheColor.safeGreen.opacity(0.28) : QiheColor.riskOrange.opacity(0.32),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(isFilled ? QiheColor.safeGreen : QiheColor.riskOrange)
                    .frame(height: 1.5)
                    .padding(.horizontal, 7)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 3)
        .accessibilityLabel(isFilled ? "\(name)，已填写" : "\(name)，待补充")
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
                .font(paragraphFont(for: segment.text))
                .foregroundStyle(QiheColor.inkSoft)
                .lineSpacing(isLikelySectionHeading(segment.text) ? 2 : 10)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, isLikelySectionHeading(segment.text) ? 8 : 6)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .background(
            isEdited
                ? QiheColor.safeGreenSoft.opacity(0.42)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .leading) {
            if isEdited {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(QiheColor.safeGreen)
                    .frame(width: 3)
                    .padding(.vertical, 5)
            }
        }
    }

    private func paragraphFont(for text: String) -> Font {
        isLikelySectionHeading(text)
            ? QiheFont.h3(size: 16, weight: .semibold)
            : QiheFont.contractDocument(size: 15)
    }

    private func isLikelySectionHeading(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count <= 28 else { return false }
        return trimmed.hasPrefix("第") && (trimmed.contains("条") || trimmed.contains("章") || trimmed.contains("节"))
    }

    // MARK: - Edit Actions

    /// 应用占位符编辑
    private func applyPlaceholderEdit(segment: DocumentSegment, name: String, value: String) {
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            applyPlaceholderClear(segment: segment, name: name)
            return
        }

        fieldValues[name] = cleaned

        var updatedSegments = segments
        if let idx = updatedSegments.firstIndex(where: { $0.id == segment.id }) {
            var updated = updatedSegments[idx]
            updated.text = cleaned
            updated.revisionState = .confirmed
            updatedSegments[idx] = updated
        }
        replaceSegments(with: updatedSegments)
    }

    /// 清空占位符（恢复待补充状态）
    private func applyPlaceholderClear(segment: DocumentSegment, name: String) {
        fieldValues.removeValue(forKey: name)

        var updatedSegments = segments
        if let idx = updatedSegments.firstIndex(where: { $0.id == segment.id }) {
            var updated = updatedSegments[idx]
            updated.text = updated.originalText
            updated.revisionState = .original
            updatedSegments[idx] = updated
        }
        replaceSegments(with: updatedSegments)
    }

    /// 应用普通段落编辑
    private func applyParagraphEdit(segment: DocumentSegment, newText: String) {
        var updatedSegments = segments
        if let idx = updatedSegments.firstIndex(where: { $0.id == segment.id }) {
            var updated = updatedSegments[idx]
            updated.text = newText
            updated.revisionState = .confirmed
            updatedSegments[idx] = updated
        }
        replaceSegments(with: updatedSegments)

        if !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            editedParagraphIds.insert(segment.id)
        }
    }

    private func replaceSegments(with updatedSegments: [DocumentSegment]) {
        segments = updatedSegments
        onDraftChange(renderedDraft(from: updatedSegments))
    }

    private func renderedDraft(from updatedSegments: [DocumentSegment]) -> String {
        guard preParsedSegments == nil else {
            return updatedSegments.map(\.text).joined(separator: "\n\n")
        }

        var rendered = ""
        var cursor = draft.startIndex
        for segment in updatedSegments {
            guard let range = draft.range(
                of: segment.originalText,
                range: cursor..<draft.endIndex
            ) else {
                return updatedSegments.map(\.text).joined(separator: "\n\n")
            }
            rendered += draft[cursor..<range.lowerBound]
            rendered += segment.text
            cursor = range.upperBound
        }
        rendered += draft[cursor..<draft.endIndex]
        return rendered
    }
}

// MARK: - InlinePlaceholderFillSheet

/// 轻量填写浮层：保留占位符保存/清空的数据流，呈现上更像直接在合同里填写。
private struct InlinePlaceholderFillSheet: View {
    let placeholderName: String
    let currentValue: String
    let onSave: (String) -> Void
    let onClear: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule()
                .fill(QiheColor.lineStrong.opacity(0.65))
                .frame(width: 38, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            HStack(alignment: .center, spacing: 10) {
                Image(systemName: currentValue.isEmpty ? "square.and.pencil" : "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(currentValue.isEmpty ? QiheColor.riskOrange : QiheColor.safeGreen)
                    .frame(width: 30, height: 30)
                    .background(currentValue.isEmpty ? QiheColor.riskOrangeSoft : QiheColor.safeGreenSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentValue.isEmpty ? "待填写" : "修改填写内容")
                        .font(QiheFont.caption(size: 12, weight: .semibold))
                        .foregroundStyle(currentValue.isEmpty ? QiheColor.riskOrange : QiheColor.safeGreen)

                    Text(placeholderName)
                        .font(QiheFont.body(size: 16, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }

                Spacer(minLength: 0)
            }

            TextField("直接填写\(placeholderName)", text: $editText, axis: .vertical)
                .font(QiheFont.body(size: 16))
                .foregroundStyle(QiheColor.ink)
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .padding(.horizontal, 13)
                .padding(.vertical, 11)
                .background(QiheColor.paper)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: QiheRadius.input, style: .continuous)
                        .stroke(QiheColor.glassStroke, lineWidth: 1)
                )

            HStack(spacing: 10) {
                if !currentValue.isEmpty {
                    Button {
                        onClear()
                        dismiss()
                    } label: {
                        Label("清空", systemImage: "arrow.uturn.backward")
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                    .font(QiheFont.body(size: 14, weight: .semibold))
                    .foregroundStyle(QiheColor.riskOrange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(QiheColor.riskOrangeSoft)
                    .clipShape(RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous))
                }

                Button {
                    dismiss()
                } label: {
                    Text("跳过")
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .font(QiheFont.body(size: 14, weight: .semibold))
                .foregroundStyle(QiheColor.muted)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(QiheColor.neutral100.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous))

                Button {
                    onSave(editText)
                    dismiss()
                } label: {
                    Label("确认填写", systemImage: "checkmark")
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(QiheFont.body(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(QiheColor.primaryGradient)
                .clipShape(RoundedRectangle(cornerRadius: QiheRadius.cta, style: .continuous))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .background(QiheColor.card)
        .onAppear {
            editText = currentValue
        }
        .presentationDetents([.height(currentValue.isEmpty ? 236 : 246), .medium])
        .presentationDragIndicator(.hidden)
    }
}
