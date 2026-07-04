import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord]

    private let storageKey = "qihe.local.history.records"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? decoder.decode([HistoryRecord].self, from: data) {
            records = decoded.sorted { $0.createdAt > $1.createdAt }
        } else {
            records = []
        }
    }

    func list() -> [HistoryRecord] {
        records
    }

    func record(id: UUID) -> HistoryRecord? {
        records.first { $0.id == id }
    }

    @discardableResult
    func addChat(messages: [ChatMessage], title: String) -> HistoryRecord {
        save(
            HistoryRecord(
                id: UUID(),
                type: .chat,
                title: title,
                createdAt: Date(),
                textPreview: messages.last?.content ?? "",
                chatMessages: messages,
                reviewResult: nil,
                generateResult: nil
            )
        )
    }

    @discardableResult
    func addReview(_ result: ReviewResult) -> HistoryRecord {
        save(
            HistoryRecord(
                id: UUID(),
                type: .review,
                title: result.title,
                createdAt: Date(),
                textPreview: result.source.textPreview,
                chatMessages: [],
                reviewResult: result,
                generateResult: nil
            )
        )
    }

    @discardableResult
    func addGenerate(_ result: GenerateResult) -> HistoryRecord {
        save(
            HistoryRecord(
                id: UUID(),
                type: .generate,
                title: result.title,
                createdAt: Date(),
                textPreview: result.source.textPreview,
                chatMessages: [],
                reviewResult: nil,
                generateResult: result
            )
        )
    }

    func clear() {
        records = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private func save(_ record: HistoryRecord) -> HistoryRecord {
        records.removeAll { $0.id == record.id }
        records.insert(record, at: 0)
        persist()
        return record
    }

    private func persist() {
        guard let data = try? encoder.encode(records) else {
            return
        }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
