import Foundation

enum HistoryKind: String, Codable, CaseIterable, Hashable {
    case chat
    case review
    case generate

    var title: String {
        switch self {
        case .chat:
            return "过程对话"
        case .review:
            return "合同审查"
        case .generate:
            return "合同生成"
        }
    }
}

enum ContractMode: String, Codable, Hashable {
    case review
    case generate
}

enum ReviewPerspective: String, Codable, Hashable, CaseIterable {
    case partyA = "party_a"
    case partyB = "party_b"
    case neutral

    var label: String {
        switch self {
        case .partyA:
            return "我是甲方"
        case .partyB:
            return "我是乙方"
        case .neutral:
            return "中立角度"
        }
    }
}

enum ChatRole: String, Codable, Hashable {
    case system
    case user
    case assistant
}

struct ChatMessage: Identifiable, Codable, Hashable {
    var id: UUID
    var role: ChatRole
    var content: String
    var createdAt: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, createdAt: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct ChatAPIMessage: Codable, Hashable {
    let role: ChatRole
    let content: String
}

struct ChatRequest: Codable, Hashable {
    let messages: [ChatAPIMessage]
}

struct ChatResponse: Decodable, Hashable {
    let type: String
    let intent: String
    let reply: String
    let route: ContractMode?
    let needInput: [String]
    let options: [ContractMode]

    enum CodingKeys: String, CodingKey {
        case type
        case intent
        case reply
        case route
        case needInput
        case needInputSnake = "need_input"
        case options
    }

    init(
        type: String = "chat",
        intent: String = "",
        reply: String,
        route: ContractMode? = nil,
        needInput: [String] = [],
        options: [ContractMode] = []
    ) {
        self.type = type
        self.intent = intent
        self.reply = reply
        self.route = route
        self.needInput = needInput
        self.options = options
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "chat"
        intent = try container.decodeIfPresent(String.self, forKey: .intent) ?? ""
        reply = try container.decodeIfPresent(String.self, forKey: .reply) ?? ""
        route = try container.decodeIfPresent(ContractMode.self, forKey: .route)
        needInput = try container.decodeIfPresent([String].self, forKey: .needInput)
            ?? container.decodeIfPresent([String].self, forKey: .needInputSnake)
            ?? []
        options = try container.decodeIfPresent([ContractMode].self, forKey: .options) ?? []
    }
}

struct UploadedFile: Identifiable, Codable, Hashable {
    var id: UUID
    var fileId: String
    var filename: String
    var contentType: String?
    var status: String

    init(id: UUID = UUID(), fileId: String, filename: String, contentType: String?, status: String) {
        self.id = id
        self.fileId = fileId
        self.filename = filename
        self.contentType = contentType
        self.status = status
    }
}

struct ContractRunRequest: Codable, Hashable {
    let mode: ContractMode
    let text: String?
    let fileId: String?
    let metadata: [String: JSONValue]
}

struct ContractRunResponse<Result: Codable & Hashable>: Decodable, Hashable {
    let type: String
    let intent: ContractMode
    let result: Result

    enum CodingKeys: String, CodingKey {
        case type
        case intent
        case result
        case reviewResult
        case generateResult
    }

    init(type: String, intent: ContractMode, result: Result) {
        self.type = type
        self.intent = intent
        self.result = result
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        intent = try container.decode(ContractMode.self, forKey: .intent)

        if let directResult = try container.decodeIfPresent(Result.self, forKey: .result) {
            result = directResult
            return
        }

        switch intent {
        case .review:
            if let reviewResult = try container.decodeIfPresent(Result.self, forKey: .reviewResult) {
                result = reviewResult
                return
            }
        case .generate:
            if let generateResult = try container.decodeIfPresent(Result.self, forKey: .generateResult) {
                result = generateResult
                return
            }
        }

        throw DecodingError.keyNotFound(
            CodingKeys.result,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Missing contract result payload"
            )
        )
    }
}

struct ContractExportRequest<Payload: Codable & Hashable>: Codable, Hashable {
    let type: ContractMode
    let title: String
    let payload: Payload
}

struct ContractSource: Codable, Hashable {
    var textPreview: String?
    var fileId: String?
    var filename: String?
    var originalText: String?
}

enum RiskLevel: String, Codable, CaseIterable, Hashable {
    case high
    case medium
    case low
    case pending
    case unknown

    init(label: String?) {
        let normalized = (label ?? "").trimmedForInput.lowercased()
        switch normalized {
        case "high", "高", "高风险", "高風險", "严重":
            self = .high
        case "medium", "mid", "中", "中风险", "中風險", "中等风险":
            self = .medium
        case "low", "低", "低风险", "低風險":
            self = .low
        case "pending", "待审查", "待確認", "待确认", "待定":
            self = .pending
        default:
            self = .unknown
        }
    }

    var label: String {
        switch self {
        case .high:
            return "高风险"
        case .medium:
            return "中风险"
        case .low:
            return "低风险"
        case .pending:
            return "未评级"
        case .unknown:
            return "未标注"
        }
    }
}

struct RiskItem: Identifiable, Codable, Hashable {
    var id: UUID
    var riskTitle: String?
    var clause: String?
    var risk: String?
    var riskAnalysis: String?
    var riskLevel: RiskLevel
    var suggestion: String?
    var revisionSuggestion: String?
    var suggestedReplacement: String?
    var basis: String?
    var legalBasis: [String]?
    var originalText: String?
    var clauseId: String?
    var clauseTitle: String?
    var originalExcerpt: String?
    var startOffset: Int?
    var endOffset: Int?

    init(
        id: UUID = UUID(),
        riskTitle: String? = nil,
        clause: String? = nil,
        risk: String? = nil,
        riskAnalysis: String? = nil,
        riskLevel: RiskLevel = .unknown,
        suggestion: String? = nil,
        revisionSuggestion: String? = nil,
        suggestedReplacement: String? = nil,
        basis: String? = nil,
        legalBasis: [String]? = nil,
        originalText: String? = nil,
        clauseId: String? = nil,
        clauseTitle: String? = nil,
        originalExcerpt: String? = nil,
        startOffset: Int? = nil,
        endOffset: Int? = nil
    ) {
        self.id = id
        self.riskTitle = riskTitle
        self.clause = clause
        self.risk = risk
        self.riskAnalysis = riskAnalysis
        self.riskLevel = riskLevel
        self.suggestion = suggestion
        self.revisionSuggestion = revisionSuggestion
        self.suggestedReplacement = suggestedReplacement
        self.basis = basis
        self.legalBasis = legalBasis
        self.originalText = originalText
        self.clauseId = clauseId
        self.clauseTitle = clauseTitle
        self.originalExcerpt = originalExcerpt
        self.startOffset = startOffset
        self.endOffset = endOffset
    }

    enum CodingKeys: String, CodingKey {
        case riskTitle
        case riskTitleSnake = "risk_title"
        case title
        case clause
        case risk
        case riskAnalysis
        case riskAnalysisSnake = "risk_analysis"
        case description
        case riskLevel
        case riskLevelSnake = "risk_level"
        case severity
        case level
        case suggestion
        case revisionSuggestion
        case revisionSuggestionSnake = "revision_suggestion"
        case suggestedReplacement
        case suggestedReplacementSnake = "suggested_replacement"
        case replacement
        case basis
        case legalBasis
        case legalBasisSnake = "legal_basis"
        case originalText
        case originalTextSnake = "original_text"
        case text
        case clauseId
        case clauseIdSnake = "clause_id"
        case clauseTitle
        case clauseTitleSnake = "clause_title"
        case originalExcerpt
        case originalExcerptSnake = "original_excerpt"
        case startOffset
        case startOffsetSnake = "start_offset"
        case endOffset
        case endOffsetSnake = "end_offset"
    }

    var displayTitle: String {
        riskTitle?.nilIfBlank
            ?? clause?.nilIfBlank
            ?? risk?.nilIfBlank
            ?? "未命名风险"
    }

    var displayAnalysis: String? {
        riskAnalysis?.nilIfBlank ?? risk?.nilIfBlank
    }

    var displaySuggestion: String? {
        revisionSuggestion?.nilIfBlank ?? suggestion?.nilIfBlank
    }

    var displayLegalBasis: String? {
        if let legalBasis, !legalBasis.isEmpty {
            let joined = legalBasis.compactMap(\.nilIfBlank).joined(separator: " · ")
            return joined.nilIfBlank
        }
        return basis?.nilIfBlank
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        riskTitle = try container.decodeStringIfPresent(forKeys: [.riskTitle, .riskTitleSnake, .title])
        clause = try container.decodeIfPresent(String.self, forKey: .clause)
        risk = try container.decodeStringIfPresent(forKeys: [.risk])
        riskAnalysis = try container.decodeStringIfPresent(forKeys: [.riskAnalysis, .riskAnalysisSnake, .description])
        let levelLabel = try container.decodeStringIfPresent(forKeys: [.riskLevel, .riskLevelSnake, .severity, .level])
        riskLevel = RiskLevel(label: levelLabel)
        suggestion = try container.decodeStringIfPresent(forKeys: [.suggestion])
        revisionSuggestion = try container.decodeStringIfPresent(forKeys: [.revisionSuggestion, .revisionSuggestionSnake])
        suggestedReplacement = try container.decodeStringIfPresent(forKeys: [.suggestedReplacement, .suggestedReplacementSnake, .replacement])
        basis = try container.decodeStringIfPresent(forKeys: [.basis])
        legalBasis = try container.decodeStringListIfPresent(forKeys: [.legalBasis, .legalBasisSnake])
        originalText = try container.decodeStringIfPresent(forKeys: [.originalText, .originalTextSnake, .text])
        clauseId = try container.decodeStringIfPresent(forKeys: [.clauseId, .clauseIdSnake])
        clauseTitle = try container.decodeStringIfPresent(forKeys: [.clauseTitle, .clauseTitleSnake])
        originalExcerpt = try container.decodeStringIfPresent(forKeys: [.originalExcerpt, .originalExcerptSnake])
        startOffset = try container.decodeIntIfPresent(forKeys: [.startOffset, .startOffsetSnake])
        endOffset = try container.decodeIntIfPresent(forKeys: [.endOffset, .endOffsetSnake])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(riskTitle, forKey: .riskTitle)
        try container.encodeIfPresent(clause, forKey: .clause)
        try container.encodeIfPresent(risk, forKey: .risk)
        try container.encodeIfPresent(riskAnalysis, forKey: .riskAnalysis)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encodeIfPresent(suggestion, forKey: .suggestion)
        try container.encodeIfPresent(revisionSuggestion, forKey: .revisionSuggestion)
        try container.encodeIfPresent(suggestedReplacement, forKey: .suggestedReplacement)
        try container.encodeIfPresent(basis, forKey: .basis)
        try container.encodeIfPresent(legalBasis, forKey: .legalBasis)
        try container.encodeIfPresent(originalText, forKey: .originalText)
        try container.encodeIfPresent(clauseId, forKey: .clauseId)
        try container.encodeIfPresent(clauseTitle, forKey: .clauseTitle)
        try container.encodeIfPresent(originalExcerpt, forKey: .originalExcerpt)
        try container.encodeIfPresent(startOffset, forKey: .startOffset)
        try container.encodeIfPresent(endOffset, forKey: .endOffset)
    }
}

struct ReviewResult: Codable, Hashable {
    var title: String?
    var summary: String?
    var reviewBasis: String?
    var riskLevel: RiskLevel?
    var score: Int?
    var riskCount: Int?
    var source: ContractSource?
    var clauseReviews: [RiskItem]?
    var parties: JSONValue?

    var displayTitle: String {
        title?.nilIfBlank ?? "合同审查报告"
    }

    var sourceText: String {
        source?.originalText?.nilIfBlank
            ?? source?.textPreview?.nilIfBlank
            ?? "暂无原文摘要。"
    }

    var risks: [RiskItem] {
        clauseReviews ?? []
    }

    var displayedRiskCount: Int {
        riskCount ?? risks.count
    }

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case reviewBasis
        case reviewBasisSnake = "review_basis"
        case riskLevel
        case riskLevelSnake = "risk_level"
        case score
        case riskCount
        case riskCountSnake = "risk_count"
        case source
        case clauseReviews
        case clauseReviewsSnake = "clause_reviews"
        case riskItems
        case riskItemsSnake = "risk_items"
        case parties
    }

    init(
        title: String? = nil,
        summary: String? = nil,
        reviewBasis: String? = nil,
        riskLevel: RiskLevel? = nil,
        score: Int? = nil,
        riskCount: Int? = nil,
        source: ContractSource? = nil,
        clauseReviews: [RiskItem]? = nil,
        parties: JSONValue? = nil
    ) {
        self.title = title
        self.summary = summary
        self.reviewBasis = reviewBasis
        self.riskLevel = riskLevel
        self.score = score
        self.riskCount = riskCount
        self.source = source
        self.clauseReviews = clauseReviews
        self.parties = parties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        reviewBasis = try container.decodeStringIfPresent(forKeys: [.reviewBasis, .reviewBasisSnake])
        riskLevel = RiskLevel(label: try container.decodeStringIfPresent(forKeys: [.riskLevel, .riskLevelSnake]))
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        riskCount = try container.decodeIntIfPresent(forKeys: [.riskCount, .riskCountSnake])
        source = try container.decodeIfPresent(ContractSource.self, forKey: .source)
        clauseReviews = try container.decodeIfPresent([RiskItem].self, forKeys: [
            .clauseReviews,
            .clauseReviewsSnake,
            .riskItems,
            .riskItemsSnake
        ])
        parties = try container.decodeIfPresent(JSONValue.self, forKey: .parties)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(reviewBasis, forKey: .reviewBasis)
        try container.encodeIfPresent(riskLevel, forKey: .riskLevel)
        try container.encodeIfPresent(score, forKey: .score)
        try container.encodeIfPresent(riskCount, forKey: .riskCount)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(clauseReviews, forKey: .clauseReviews)
        try container.encodeIfPresent(parties, forKey: .parties)
    }
}

extension ReviewResult {
    func repairingWeakFallback(requestText: String?, attachment: UploadedFile?) -> ReviewResult {
        guard isWeakFallback else {
            return self
        }

        let evidence = fallbackEvidenceText(requestText: requestText)
        let fallbackRisks = ClientReviewFallback.buildRisks(from: evidence)
        guard !fallbackRisks.isEmpty else {
            return self
        }

        var repaired = self
        repaired.summary = "AI 输出暂时未能稳定解析，已根据合同文本提取重点核对项。AI 辅助审查，不构成法律意见。"
        repaired.reviewBasis = "基于已抽取合同文本进行结构化处理；当前启用本地风险兜底识别。AI 辅助审查，不构成法律意见。"
        repaired.riskLevel = ClientReviewFallback.overallLevel(for: fallbackRisks)
        repaired.score = ClientReviewFallback.score(for: repaired.riskLevel)
        repaired.riskCount = fallbackRisks.count
        repaired.clauseReviews = fallbackRisks
        if repaired.source?.filename == nil, let attachment {
            repaired.source?.filename = attachment.filename
        }
        return repaired
    }

    private var isWeakFallback: Bool {
        let text = [
            summary,
            reviewBasis,
            clauseReviews?.first?.riskTitle,
            clauseReviews?.first?.riskAnalysis,
            clauseReviews?.first?.revisionSuggestion
        ]
        .compactMap { $0?.nilIfBlank }
        .joined(separator: "\n")

        if text.contains("AI 输出暂时未能稳定解析")
            || text.contains("审查结果待确认")
            || text.contains("待确认的结构化审查结果") {
            return true
        }

        return (riskLevel == .pending || riskLevel == .unknown)
            && (score == nil || score == 0)
            && risks.count <= 1
    }

    private func fallbackEvidenceText(requestText: String?) -> String {
        [
            source?.originalText,
            requestText,
            source?.textPreview,
            clauseReviews?.compactMap { item in
                [
                    item.originalExcerpt,
                    item.originalText,
                    item.clause
                ]
                .compactMap(\.self)
                .joined(separator: "\n")
            }
            .joined(separator: "\n")
        ]
        .compactMap { $0?.nilIfBlank }
        .joined(separator: "\n")
    }
}

private enum ClientReviewFallback {
    private struct Rule {
        let id: String
        let keywords: [String]
        let title: String
        let level: RiskLevel
        let analysis: String
        let suggestion: String
        let basis: [String]
    }

    private static let rules: [Rule] = [
        Rule(
            id: "payment",
            keywords: ["付款", "支付", "价款", "金额", "总金额", "合同金额", "人民币", "¥", "￥", "发票", "结算"],
            title: "付款金额与结算安排需核对",
            level: .medium,
            analysis: "合同涉及金额、付款或结算信息，若付款节点、验收条件、发票要求或逾期后果不清，容易引发履行争议。",
            suggestion: "明确总金额、付款节点、付款条件、发票类型、逾期付款责任以及与验收结果的关联。",
            basis: ["民法典合同编关于价款、履行和违约责任的一般规则"]
        ),
        Rule(
            id: "acceptance",
            keywords: ["验收", "交付", "交货", "履行期限", "服务期限", "质量", "标准", "成果", "完成", "签收"],
            title: "交付验收标准需明确",
            level: .medium,
            analysis: "合同涉及交付、服务或验收内容，若验收标准、验收期限、整改流程或交付成果边界不清，可能影响付款和责任认定。",
            suggestion: "补充交付清单、验收标准、验收期限、异议处理、整改次数和最终确认方式。",
            basis: ["民法典合同编关于履行质量、履行期限和验收的一般规则"]
        ),
        Rule(
            id: "breach",
            keywords: ["违约", "赔偿", "责任", "罚金", "违约金", "滞纳金", "解除", "终止", "不退", "扣除", "损失"],
            title: "违约责任与解除条件需核对",
            level: .medium,
            analysis: "合同出现违约责任、赔偿、解除或扣除安排，需要确认责任触发条件、责任上限和解除程序是否对等、清楚。",
            suggestion: "明确违约情形、通知与补救期限、违约金计算方式、损失赔偿范围、解除条件和责任上限。",
            basis: ["民法典合同编关于违约责任、合同解除和损害赔偿的一般规则"]
        ),
        Rule(
            id: "dispute",
            keywords: ["争议", "仲裁", "诉讼", "法院", "管辖", "法律适用", "协商", "纠纷"],
            title: "争议解决条款需核对",
            level: .low,
            analysis: "合同涉及争议解决安排，应确认管辖机构、适用法律和争议处理路径是否明确且可执行。",
            suggestion: "写明协商期限、管辖法院或仲裁机构、适用法律、送达地址及通知方式。",
            basis: ["民事诉讼法及民法典合同编关于争议解决和通知送达的一般规则"]
        ),
        Rule(
            id: "procurement",
            keywords: ["政府采购", "采购法", "采购合同", "招标", "投标", "中标", "供应商", "采购人", "财政"],
            title: "政府采购合规要求需复核",
            level: .medium,
            analysis: "文本涉及政府采购或招投标场景，需要复核合同内容是否与采购文件、中标结果、预算金额和法定采购程序保持一致。",
            suggestion: "核对采购项目编号、采购文件、中标通知、服务范围、金额、履约验收、付款条件和变更审批流程。",
            basis: ["政府采购法及其实施条例关于采购合同、履约验收和变更管理的一般要求"]
        ),
        Rule(
            id: "confidentiality",
            keywords: ["保密", "知识产权", "著作权", "数据", "资料", "商业秘密", "隐私", "个人信息"],
            title: "保密与资料权属需核对",
            level: .low,
            analysis: "合同涉及资料、数据、知识产权或保密内容，应明确使用范围、权属归属、保密期限和泄露责任。",
            suggestion: "补充资料交付、使用授权、成果权属、保密期限、例外情形和违约责任。",
            basis: ["民法典合同编及知识产权、个人信息保护相关规则的一般要求"]
        )
    ]

    static func buildRisks(from text: String) -> [RiskItem] {
        guard let text = text.nilIfBlank else {
            return []
        }

        var items: [RiskItem] = []
        for rule in rules {
            guard let match = excerpt(in: text, for: rule.keywords) else {
                continue
            }
            items.append(
                RiskItem(
                    riskTitle: rule.title,
                    clause: match.excerpt,
                    riskAnalysis: "本地兜底识别：\(rule.analysis)",
                    riskLevel: rule.level,
                    revisionSuggestion: rule.suggestion,
                    legalBasis: rule.basis,
                    originalExcerpt: match.excerpt,
                    startOffset: match.start,
                    endOffset: match.end
                )
            )
            if items.count >= 4 {
                break
            }
        }

        if items.isEmpty {
            items.append(
                RiskItem(
                    riskTitle: "合同关键条款需人工复核",
                    clause: String(text.prefix(180)),
                    riskAnalysis: "服务端模型输出暂时未能稳定解析，当前保留原文摘录供继续核对。",
                    riskLevel: .pending,
                    revisionSuggestion: "请重点核对主体、金额、期限、履行方式、违约责任和争议解决条款，必要时补充更完整文本后重新审查。",
                    legalBasis: ["待确认：需结合具体事实和适用法律进一步核对"],
                    originalExcerpt: String(text.prefix(180)),
                    startOffset: text.isEmpty ? nil : 0,
                    endOffset: text.isEmpty ? nil : min(text.count, 180)
                )
            )
        }

        return items
    }

    static func overallLevel(for risks: [RiskItem]) -> RiskLevel {
        if risks.contains(where: { $0.riskLevel == .high }) {
            return .high
        }
        if risks.contains(where: { $0.riskLevel == .medium }) {
            return .medium
        }
        if risks.contains(where: { $0.riskLevel == .low }) {
            return .low
        }
        return .pending
    }

    static func score(for level: RiskLevel?) -> Int? {
        switch level {
        case .high:
            return 58
        case .medium:
            return 72
        case .low:
            return 86
        case .pending, .unknown, nil:
            return nil
        }
    }

    private static func excerpt(in text: String, for keywords: [String]) -> (excerpt: String, start: Int?, end: Int?)? {
        for keyword in keywords {
            guard let range = text.range(of: keyword, options: [.caseInsensitive, .diacriticInsensitive]) else {
                continue
            }

            let window = windowAround(range: range, in: text)
            return (window.excerpt, window.start, window.end)
        }
        return nil
    }

    private static func windowAround(range: Range<String.Index>, in text: String) -> (excerpt: String, start: Int?, end: Int?) {
        let separators = CharacterSet(charactersIn: "\n。；;")
        var lower = range.lowerBound
        var cursor = range.lowerBound
        while cursor > text.startIndex {
            let previous = text.index(before: cursor)
            if String(text[previous]).rangeOfCharacter(from: separators) != nil {
                lower = cursor
                break
            }
            lower = previous
            cursor = previous
            if text.distance(from: lower, to: range.lowerBound) >= 90 {
                break
            }
        }

        var upper = range.upperBound
        cursor = range.upperBound
        while cursor < text.endIndex {
            if String(text[cursor]).rangeOfCharacter(from: separators) != nil {
                upper = text.index(after: cursor)
                break
            }
            upper = text.index(after: cursor)
            cursor = upper
            if text.distance(from: range.upperBound, to: upper) >= 180 {
                break
            }
        }

        let excerpt = String(text[lower..<upper])
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .truncated(to: 260)
        let start = text.distance(from: text.startIndex, to: lower)
        let end = min(text.count, start + excerpt.count)
        return (excerpt, start, end)
    }
}

struct GenerateResult: Codable, Hashable {
    var title: String?
    var draft: String?
    var missingFields: [String]?
    var preSignChecklist: [String]?
    var source: ContractSource?

    var displayTitle: String {
        title?.nilIfBlank ?? "合同草案"
    }

    var fieldsToComplete: [String] {
        missingFields ?? []
    }

    var checklist: [String] {
        preSignChecklist ?? []
    }
}

struct ChatHistoryPayload: Codable, Hashable {
    var messages: [ChatMessage]
}

struct ReviewHistoryPayload: Codable, Hashable {
    var requestText: String
    var attachment: UploadedFile?
    var result: ReviewResult
    var reviewPerspective: ReviewPerspective?
}

struct GenerateHistoryPayload: Codable, Hashable {
    var requestText: String
    var attachment: UploadedFile?
    var result: GenerateResult
}

struct HistoryRecord: Identifiable, Codable, Hashable {
    var id: UUID
    var type: HistoryKind
    var title: String
    var subtitle: String
    var preview: String
    var createdAt: Date
    var updatedAt: Date
    var chatPayload: ChatHistoryPayload?
    var reviewPayload: ReviewHistoryPayload?
    var generatePayload: GenerateHistoryPayload?

    init(
        id: UUID = UUID(),
        type: HistoryKind,
        title: String,
        subtitle: String = "",
        preview: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        chatPayload: ChatHistoryPayload? = nil,
        reviewPayload: ReviewHistoryPayload? = nil,
        generatePayload: GenerateHistoryPayload? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.preview = preview
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.chatPayload = chatPayload
        self.reviewPayload = reviewPayload
        self.generatePayload = generatePayload
    }
}

enum JSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var displayString: String {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case let .bool(value):
            return value ? "是" : "否"
        case let .object(value):
            if value.isEmpty {
                return "暂无主体信息。"
            }
            return value
                .sorted { $0.key < $1.key }
                .map { "\($0.key)：\($0.value.displayString)" }
                .joined(separator: "\n")
        case let .array(value):
            if value.isEmpty {
                return "暂无信息。"
            }
            return value.map(\.displayString).joined(separator: "\n")
        case .null:
            return "暂无信息。"
        }
    }

    var subjectFacts: [ContractSubjectFact] {
        guard case let .object(values) = self else {
            return []
        }

        return ContractSubjectField.allCases.compactMap { field in
            guard let value = values.subjectValue(for: field)?.nilIfBlank else {
                return nil
            }
            return ContractSubjectFact(field: field, value: value)
        }
    }

    var hasIncompleteCoreSubjectInfo: Bool {
        guard case let .object(values) = self else {
            return true
        }

        return ContractSubjectField.coreFields.contains { field in
            values.subjectValue(for: field)?.nilIfBlank == nil
        }
    }
}

struct ContractSubjectFact: Identifiable, Hashable {
    var field: ContractSubjectField
    var value: String

    var id: String {
        field.rawValue
    }

    var label: String {
        field.label
    }
}

enum ContractSubjectField: String, CaseIterable, Hashable {
    case partyA
    case partyB
    case contractType
    case amount
    case term
    case jurisdiction

    static let coreFields: [ContractSubjectField] = [.partyB, .amount, .term]

    var label: String {
        switch self {
        case .partyA:
            return "甲方"
        case .partyB:
            return "乙方"
        case .contractType:
            return "合同类型"
        case .amount:
            return "金额"
        case .term:
            return "期限"
        case .jurisdiction:
            return "司法辖区"
        }
    }

    var lookupKeys: [String] {
        switch self {
        case .partyA:
            return ["甲方", "party_a", "partyA", "出租方", "委托方", "买方"]
        case .partyB:
            return ["乙方", "party_b", "partyB", "承租方", "受托方", "卖方"]
        case .contractType:
            return ["合同类型", "contract_type", "contractType", "类型"]
        case .amount:
            return ["金额", "合同金额", "amount", "价款", "租金", "总价"]
        case .term:
            return ["期限", "合同期限", "term", "履行期限", "租赁期限"]
        case .jurisdiction:
            return ["司法辖区", "jurisdiction", "适用法律", "管辖", "争议解决"]
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func subjectValue(for field: ContractSubjectField) -> String? {
        for key in field.lookupKeys {
            if let value = self[key]?.plainDisplayString.nilIfBlank {
                return value
            }
        }
        return nil
    }
}

private extension JSONValue {
    var plainDisplayString: String {
        switch self {
        case let .string(value):
            return value
        case let .number(value):
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        case let .bool(value):
            return value ? "是" : "否"
        case let .array(values):
            return values
                .map(\.plainDisplayString)
                .compactMap(\.nilIfBlank)
                .joined(separator: "、")
        case let .object(values):
            return values
                .sorted { $0.key < $1.key }
                .map { $0.value.plainDisplayString }
                .compactMap(\.nilIfBlank)
                .joined(separator: "、")
        case .null:
            return ""
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeStringIfPresent(forKeys keys: [Key]) throws -> String? {
        for key in keys {
            if let value = try? decodeIfPresent(String.self, forKey: key)?.nilIfBlank {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                if value.rounded() == value {
                    return String(Int(value))
                }
                return String(value)
            }
        }
        return nil
    }

    func decodeStringListIfPresent(forKeys keys: [Key]) throws -> [String]? {
        for key in keys {
            if let values = try? decodeIfPresent([String].self, forKey: key) {
                let cleaned = values.compactMap(\.nilIfBlank)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
            if let value = try? decodeIfPresent(String.self, forKey: key)?.nilIfBlank {
                return [value]
            }
        }
        return nil
    }

    func decodeIntIfPresent(forKeys keys: [Key]) throws -> Int? {
        for key in keys {
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Double.self, forKey: key) {
                return Int(value)
            }
            if let value = try? decodeIfPresent(String.self, forKey: key), let intValue = Int(value) {
                return intValue
            }
        }
        return nil
    }

    func decodeIfPresent<T: Decodable>(_ type: T.Type, forKeys keys: [Key]) throws -> T? {
        for key in keys {
            if let value = try decodeIfPresent(type, forKey: key) {
                return value
            }
        }
        return nil
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmedForInput
        return trimmed.isEmpty ? nil : trimmed
    }

    var trimmedForInput: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func truncated(to limit: Int) -> String {
        guard count > limit else {
            return self
        }
        let endIndex = index(startIndex, offsetBy: limit)
        return String(self[..<endIndex]) + "..."
    }
}
