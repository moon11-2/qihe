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
            return "待审查"
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
        originalText: String? = nil
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

enum JSONValue: Codable, Hashable {
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
