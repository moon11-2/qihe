import Foundation
import SwiftData

@Model
final class StoredHistoryRecord {
    @Attribute(.unique) var id: UUID
    var typeRaw: String
    var title: String
    var subtitle: String
    var preview: String
    var createdAt: Date
    var updatedAt: Date
    @Attribute(.externalStorage) var payloadData: Data

    init(record: HistoryRecord, encoder: JSONEncoder) {
        id = record.id
        typeRaw = record.type.rawValue
        title = record.title
        subtitle = record.subtitle
        preview = record.preview
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        payloadData = (try? encoder.encode(record)) ?? Data()
    }

    func update(with record: HistoryRecord, encoder: JSONEncoder) {
        typeRaw = record.type.rawValue
        title = record.title
        subtitle = record.subtitle
        preview = record.preview
        createdAt = record.createdAt
        updatedAt = record.updatedAt
        payloadData = (try? encoder.encode(record)) ?? Data()
    }

    func decodedRecord(decoder: JSONDecoder) -> HistoryRecord? {
        try? decoder.decode(HistoryRecord.self, from: payloadData)
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []

    private let container: ModelContainer
    private let context: ModelContext

    init(container: ModelContainer? = nil) {
        let resolvedContainer = container ?? Self.makeContainer()
        self.container = resolvedContainer
        context = ModelContext(resolvedContainer)
        load()
    }

    func list() -> [HistoryRecord] {
        records
    }

    func record(id: UUID) -> HistoryRecord? {
        records.first { $0.id == id }
    }

    @discardableResult
    func saveChat(recordId: UUID?, messages: [ChatMessage]) -> UUID {
        let id = recordId ?? UUID()
        let title = messages.first { $0.role == .user }?.content.truncated(to: 22) ?? "过程对话"
        let record = HistoryRecord(
            id: id,
            type: .chat,
            title: title,
            subtitle: "本地过程",
            preview: messages.last?.content.truncated(to: 80) ?? "",
            createdAt: records.first { $0.id == id }?.createdAt ?? Date(),
            updatedAt: Date(),
            chatPayload: ChatHistoryPayload(messages: messages)
        )
        upsert(record)
        return id
    }

    @discardableResult
    func saveReview(
        requestText: String,
        attachment: UploadedFile?,
        result: ReviewResult
    ) -> UUID {
        let record = HistoryRecord(
            type: .review,
            title: result.displayTitle,
            subtitle: attachment?.filename ?? "文本审查",
            preview: (result.summary ?? requestText).truncated(to: 88),
            reviewPayload: ReviewHistoryPayload(
                requestText: requestText,
                attachment: attachment,
                result: result
            )
        )
        upsert(record)
        return record.id
    }

    @discardableResult
    func saveGenerate(
        requestText: String,
        attachment: UploadedFile?,
        result: GenerateResult
    ) -> UUID {
        let record = HistoryRecord(
            type: .generate,
            title: result.displayTitle,
            subtitle: attachment?.filename ?? "文本生成",
            preview: (result.draft ?? requestText).truncated(to: 88),
            generatePayload: GenerateHistoryPayload(
                requestText: requestText,
                attachment: attachment,
                result: result
            )
        )
        upsert(record)
        return record.id
    }

    func clear() {
        fetchEntities().forEach { context.delete($0) }
        saveContext()
        records = []
    }

    private func upsert(_ record: HistoryRecord) {
        if let entity = fetchEntities().first(where: { $0.id == record.id }) {
            entity.update(with: record, encoder: Self.encoder)
        } else {
            context.insert(StoredHistoryRecord(record: record, encoder: Self.encoder))
        }
        saveContext()
        load()
    }

    private func load() {
        records = fetchEntities()
            .compactMap { $0.decodedRecord(decoder: Self.decoder) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func fetchEntities() -> [StoredHistoryRecord] {
        do {
            return try context.fetch(FetchDescriptor<StoredHistoryRecord>())
        } catch {
            return []
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            // Local history must not crash the app; the current UI state can still continue.
        }
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: StoredHistoryRecord.self)
        } catch {
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: StoredHistoryRecord.self, configurations: configuration)
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}
