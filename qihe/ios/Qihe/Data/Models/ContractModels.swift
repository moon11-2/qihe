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

struct ChatResponse: Codable, Hashable {
    let type: String
    let intent: String
    let reply: String
    let route: ContractMode?
    let needInput: [String]
    let options: [ContractMode]
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
        case "high", "高", "高风险", "严重":
            self = .high
        case "medium", "mid", "中", "中风险":
            self = .medium
        case "low", "低", "低风险":
            self = .low
        case "pending", "待审查", "待定":
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
    var clause: String?
    var risk: String?
    var riskLevel: RiskLevel
    var suggestion: String?
    var basis: String?
    var originalText: String?

    init(
        id: UUID = UUID(),
        clause: String? = nil,
        risk: String? = nil,
        riskLevel: RiskLevel = .unknown,
        suggestion: String? = nil,
        basis: String? = nil,
        originalText: String? = nil
    ) {
        self.id = id
        self.clause = clause
        self.risk = risk
        self.riskLevel = riskLevel
        self.suggestion = suggestion
        self.basis = basis
        self.originalText = originalText
    }

    enum CodingKeys: String, CodingKey {
        case clause
        case risk
        case riskLevel
        case severity
        case level
        case suggestion
        case basis
        case originalText
        case text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        clause = try container.decodeIfPresent(String.self, forKey: .clause)
        risk = try container.decodeIfPresent(String.self, forKey: .risk)
        let levelLabel = try container.decodeIfPresent(String.self, forKey: .riskLevel)
            ?? container.decodeIfPresent(String.self, forKey: .severity)
            ?? container.decodeIfPresent(String.self, forKey: .level)
        riskLevel = RiskLevel(label: levelLabel)
        suggestion = try container.decodeIfPresent(String.self, forKey: .suggestion)
        basis = try container.decodeIfPresent(String.self, forKey: .basis)
        originalText = try container.decodeIfPresent(String.self, forKey: .originalText)
            ?? container.decodeIfPresent(String.self, forKey: .text)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(clause, forKey: .clause)
        try container.encodeIfPresent(risk, forKey: .risk)
        try container.encode(riskLevel, forKey: .riskLevel)
        try container.encodeIfPresent(suggestion, forKey: .suggestion)
        try container.encodeIfPresent(basis, forKey: .basis)
        try container.encodeIfPresent(originalText, forKey: .originalText)
    }
}

struct ReviewResult: Codable, Hashable {
    var title: String?
    var summary: String?
    var reviewBasis: String?
    var riskLevel: RiskLevel?
    var score: Int?
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

    enum CodingKeys: String, CodingKey {
        case title
        case summary
        case reviewBasis
        case riskLevel
        case score
        case source
        case clauseReviews
        case parties
    }

    init(
        title: String? = nil,
        summary: String? = nil,
        reviewBasis: String? = nil,
        riskLevel: RiskLevel? = nil,
        score: Int? = nil,
        source: ContractSource? = nil,
        clauseReviews: [RiskItem]? = nil,
        parties: JSONValue? = nil
    ) {
        self.title = title
        self.summary = summary
        self.reviewBasis = reviewBasis
        self.riskLevel = riskLevel
        self.score = score
        self.source = source
        self.clauseReviews = clauseReviews
        self.parties = parties
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        reviewBasis = try container.decodeIfPresent(String.self, forKey: .reviewBasis)
        if let riskLabel = try container.decodeIfPresent(String.self, forKey: .riskLevel) {
            riskLevel = RiskLevel(label: riskLabel)
        } else {
            riskLevel = try container.decodeIfPresent(RiskLevel.self, forKey: .riskLevel)
        }
        score = try container.decodeIfPresent(Int.self, forKey: .score)
        source = try container.decodeIfPresent(ContractSource.self, forKey: .source)
        clauseReviews = try container.decodeIfPresent([RiskItem].self, forKey: .clauseReviews)
        parties = try container.decodeIfPresent(JSONValue.self, forKey: .parties)
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
