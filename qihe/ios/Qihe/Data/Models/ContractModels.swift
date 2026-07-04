import Foundation

struct HistoryRecord: Identifiable, Codable, Hashable {
    enum RecordType: String, Codable {
        case chat
        case review
        case generate
    }

    let id: UUID
    let type: RecordType
    let title: String
    let createdAt: Date
    let textPreview: String
    let chatMessages: [ChatMessage]
    let reviewResult: ReviewResult?
    let generateResult: GenerateResult?
}

struct HealthResponse: Decodable, Hashable {
    let status: String
    let service: String
}

struct ChatPayload: Codable, Hashable {
    let role: String
    let content: String
}

struct ChatMessage: Codable, Hashable, Identifiable {
    var id = UUID()
    let role: String
    let content: String

    enum CodingKeys: String, CodingKey {
        case role
        case content
    }
}

struct ChatRequest: Encodable {
    let messages: [ChatMessage]
}

struct ChatResponse: Decodable, Hashable {
    let type: String
    let intent: String
    let reply: String
    let route: String?
    let needInput: [String]
    let options: [String]
}

struct ContractRunRequest: Encodable {
    let mode: String
    let text: String?
    let fileId: String?
    let metadata: [String: String]
}

struct ContractRunResponse: Decodable, Hashable {
    let type: String
    let intent: String
    let reviewResult: ReviewResult?
    let generateResult: GenerateResult?
}

struct ContractSource: Codable, Hashable {
    let textPreview: String
    let fileId: String?
    let charCount: Int
}

struct ContractParties: Codable, Hashable {
    let partyA: String?
    let partyB: String?
    let amount: String?
    let term: String?
    let contractType: String?
    let jurisdiction: String?
}

struct ClauseReview: Codable, Hashable, Identifiable {
    var id = UUID()
    let riskTitle: String
    let riskLevel: String
    let clause: String?
    let riskAnalysis: String
    let revisionSuggestion: String
    let suggestedReplacement: String?
    let legalBasis: [String]

    enum CodingKeys: String, CodingKey {
        case riskTitle
        case riskLevel
        case clause
        case riskAnalysis
        case revisionSuggestion
        case suggestedReplacement
        case legalBasis
    }
}

struct ReviewResult: Codable, Hashable {
    let title: String
    let summary: String
    let reviewBasis: String
    let riskLevel: String
    let score: Int?
    let riskItems: [ClauseReview]
    let clauseReviews: [ClauseReview]
    let parties: ContractParties
    let source: ContractSource
}

struct GenerateResult: Codable, Hashable {
    let title: String
    let draft: String
    let missingFields: [String]
    let preSignChecklist: [String]
    let notes: [String]
    let source: ContractSource
}

struct FileUploadResponse: Decodable, Hashable {
    let fileId: String
    let filename: String
    let contentType: String?
    let status: String
    let textPreview: String
    let charCount: Int
}

struct BackendErrorResponse: Decodable, Hashable {
    struct Detail: Decodable, Hashable {
        let code: String
        let message: String
    }

    let error: Detail
}
