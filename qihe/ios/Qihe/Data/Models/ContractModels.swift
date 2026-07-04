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
}

struct ChatPayload: Codable, Hashable {
    let role: String
    let content: String
}

