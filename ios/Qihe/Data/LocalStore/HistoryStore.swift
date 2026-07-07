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

// MARK: - Job 轮询管理器（任务四）

/// 异步任务轮询管理器：定期向后端查询 job 状态
@MainActor
final class JobPollingStore: ObservableObject {
    @Published private(set) var currentJob: ContractJob?
    @Published private(set) var currentStep: String = "正在提交..."
    @Published private(set) var isPolling = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var completedRecordId: UUID?
    @Published private(set) var completedMode: ContractMode?

    private var timer: Timer?
    private var pollCount = 0
    private let maxPolls = 200
    private let interval: TimeInterval = 1.5

    var apiClient: APIClient?
    var historyStore: HistoryStore?

    func startPolling(jobId: String, mode: ContractMode) {
        stopPolling()
        currentJob = ContractJob(id: jobId, status: .queued, mode: mode)
        currentStep = mode == .review ? "正在提交审查..." : "正在提交生成..."
        errorMessage = nil
        completedRecordId = nil
        completedMode = nil
        isPolling = true
        pollCount = 0
        schedulePoll()
    }

    func stopPolling() {
        timer?.invalidate()
        timer = nil
        isPolling = false
    }

    func cancelPolling() {
        stopPolling()
        currentJob = nil
        currentStep = ""
        errorMessage = nil
    }

    private func schedulePoll() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.poll() }
        }
    }

    private func poll() async {
        guard isPolling, let jobId = currentJob?.id, let apiClient else { return }
        pollCount += 1
        guard pollCount <= maxPolls else {
            await finishWithError("处理超时，请稍后重试。")
            return
        }
        do {
            let job = try await apiClient.pollJob(jobId: jobId)
            currentJob = job
            currentStep = job.step ?? defaultStep(for: job.status, mode: job.mode)
            switch job.status {
            case .queued, .running: schedulePoll()
            case .succeeded: await handleSucceeded(job)
            case .failed: await finishWithError(job.errorMessage ?? "任务处理失败，请稍后重试。")
            }
        } catch {
            if isCancellation(error) { return }
            schedulePoll()
        }
    }

    private func defaultStep(for status: JobStatus, mode: ContractMode?) -> String {
        let isReview = mode == .review
        switch status {
        case .queued: return isReview ? "审查任务排队中..." : "生成任务排队中..."
        case .running: return isReview ? "正在分析合同..." : "正在起草合同..."
        case .succeeded: return isReview ? "审查报告已生成" : "合同草案已生成"
        case .failed: return "任务处理失败"
        }
    }

    private func handleSucceeded(_ job: ContractJob) async {
        guard let historyStore else {
            await finishWithError("数据存储不可用。")
            return
        }
        isPolling = false
        timer?.invalidate()
        timer = nil
        let mode = job.mode ?? currentJob?.mode ?? .review
        let recordId: UUID
        switch mode {
        case .review:
            guard let result = job.reviewResult else { await finishWithError("审查结果异常。"); return }
            recordId = historyStore.saveReview(requestText: "", attachment: nil, result: result)
        case .generate:
            guard let result = job.generateResult else { await finishWithError("生成结果异常。"); return }
            recordId = historyStore.saveGenerate(requestText: "", attachment: nil, result: result)
        }
        completedRecordId = recordId
        completedMode = mode
    }

    private func finishWithError(_ message: String) async {
        isPolling = false
        timer?.invalidate()
        timer = nil
        errorMessage = message
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let urlError = error as? URLError, urlError.code == .cancelled { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
