import Foundation

// MARK: - DocumentSegment

/// 文档段落结构体，表示合同文档中的一个可编辑段落
struct DocumentSegment: Identifiable, Hashable {
    enum Kind: Hashable {
        /// 普通段落
        case paragraph
        /// 占位符，name 是占位符的名称，如"甲方名称"
        case placeholder(name: String)
    }

    /// 段落唯一标识符
    var id: String
    /// 段落类型：普通段落或占位符
    var kind: Kind
    /// 当前显示的文本内容
    var text: String
    /// 原始文本内容（用于对比和恢复）
    var originalText: String
    /// 关联的风险 ID 列表（生成场景暂不使用，预留）
    var riskIds: [String]
    /// 当前段落的修改状态
    var revisionState: RevisionState

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        text: String,
        originalText: String? = nil,
        riskIds: [String] = [],
        revisionState: RevisionState = .original
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.originalText = originalText ?? text
        self.riskIds = riskIds
        self.revisionState = revisionState
    }

    /// 占位符是否已被填写（文本与原始占位符标记不同）
    var isPlaceholderFilled: Bool {
        guard case .placeholder = kind else { return false }
        return text != originalText && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 占位符的名称（仅对 placeholder 类型有效）
    var placeholderName: String? {
        if case .placeholder(let name) = kind { return name }
        return nil
    }
}

// MARK: - Draft Parser

enum DraftSegmentParser {
    /// 占位符匹配正则：匹配 【待补充：xxx】 或 【待补充:xxx】
    private static let placeholderPattern = #"【待补充[:：]([^】]+)】"#

    /// 将合同草稿文本解析为 DocumentSegment 数组
    /// - Parameter draft: 合同草稿全文
    /// - Returns: 解析后的段落数组
    static func parse(_ draft: String) -> [DocumentSegment] {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: placeholderPattern)
        } catch {
            // 正则编译失败时，按空行拆分为普通段落
            return splitPlainParagraphs(draft)
        }

        let nsRange = NSRange(draft.startIndex..<draft.endIndex, in: draft)
        let matches = regex.matches(in: draft, range: nsRange)

        // 如果没有占位符，按空行拆分普通段落
        guard !matches.isEmpty else {
            return splitPlainParagraphs(draft)
        }

        var segments: [DocumentSegment] = []
        var currentIndex = draft.startIndex

        for match in matches {
            guard let matchRange = Range(match.range, in: draft) else { continue }

            // 占位符之前的文本 → 拆分为普通段落
            if currentIndex < matchRange.lowerBound {
                let beforeText = String(draft[currentIndex..<matchRange.lowerBound])
                segments.append(contentsOf: splitPlainParagraphs(beforeText))
            }

            // 占位符本身 → 创建 placeholder token
            let fullPlaceholder = String(draft[matchRange])

            // 提取占位符名称
            let placeholderName: String
            if match.numberOfRanges > 1, let nameRange = Range(match.range(at: 1), in: draft) {
                placeholderName = String(draft[nameRange])
            } else {
                placeholderName = "未命名"
            }

            segments.append(
                DocumentSegment(
                    kind: .placeholder(name: placeholderName),
                    text: fullPlaceholder,
                    originalText: fullPlaceholder,
                    revisionState: .original
                )
            )

            currentIndex = matchRange.upperBound
        }

        // 最后一个占位符之后的文本
        if currentIndex < draft.endIndex {
            let afterText = String(draft[currentIndex..<draft.endIndex])
            segments.append(contentsOf: splitPlainParagraphs(afterText))
        }

        return segments
    }

    /// 将纯文本按空行拆分为普通段落
    private static func splitPlainParagraphs(_ text: String) -> [DocumentSegment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 按连续空行（两个及以上换行）拆分
        let paragraphs = trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !paragraphs.isEmpty else {
            return [DocumentSegment(
                kind: .paragraph,
                text: trimmed
            )]
        }

        return paragraphs.map { text in
            DocumentSegment(
                kind: .paragraph,
                text: text
            )
        }
    }

    // MARK: - 后端 blocks 转换（任务三）

    /// 将后端 ContractBlock 数组转换为前端 DocumentSegment 数组
    /// - Parameters:
    ///   - blocks: 后端返回的段落块数组
    ///   - revisionStates: 已确认的修改状态映射 (blockId → RevisionState)，用于恢复历史状态
    /// - Returns: 转换后的 DocumentSegment 数组
    static func parse(blocks: [ContractBlock], revisionStates: [String: RevisionState] = [:]) -> [DocumentSegment] {
        blocks.map { block in
            let state = revisionStates[block.id] ?? .original
            return block.toDocumentSegment(revisionState: state)
        }
    }

    /// 生成合同场景的混合解析：优先后端 blocks，无数据时回退前端分段
    /// - Parameters:
    ///   - blocks: 后端返回的段落块（可选）
    ///   - draft: 合同草稿全文（回退用）
    ///   - revisionStates: 已确认的修改状态映射
    /// - Returns: DocumentSegment 数组
    static func parseGenerate(
        blocks: [ContractBlock]?,
        draft: String?,
        revisionStates: [String: RevisionState] = [:]
    ) -> [DocumentSegment] {
        if let blocks, !blocks.isEmpty {
            return parse(blocks: blocks, revisionStates: revisionStates)
        }
        return parse(draft ?? "")
    }
}
