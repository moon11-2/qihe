import Foundation
import SwiftData

// MARK: - SwiftData 持久化模型

@Model
final class StoredRevision {
    @Attribute(.unique) var id: UUID
    var recordId: UUID
    var segmentId: String
    var riskId: String?
    var beforeText: String
    var afterText: String
    var statusRaw: String
    var createdAt: Date
    var updatedAt: Date

    init(revision: LocalRevision) {
        id = revision.id
        recordId = revision.recordId
        segmentId = revision.segmentId
        riskId = revision.riskId
        beforeText = revision.beforeText
        afterText = revision.afterText
        statusRaw = revision.status.rawValue
        createdAt = revision.createdAt
        updatedAt = revision.updatedAt
    }

    func toLocalRevision() -> LocalRevision {
        LocalRevision(
            id: id,
            recordId: recordId,
            segmentId: segmentId,
            riskId: riskId,
            beforeText: beforeText,
            afterText: afterText,
            status: RevisionState(rawValue: statusRaw) ?? .confirmed,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - 修改记录本地存储管理器

/// 修改记录本地存储管理器，使用独立的 SwiftData ModelContainer，
/// 不与 HistoryStore 共享容器，避免模型迁移冲突。
@MainActor
final class RevisionStore: ObservableObject {
    @Published private(set) var revisions: [LocalRevision] = []

    private let container: ModelContainer
    private let context: ModelContext

    init() {
        container = Self.makeContainer()
        context = ModelContext(container)
        load()
    }

    /// 获取指定记录的所有修改
    func revisions(for recordId: UUID) -> [LocalRevision] {
        revisions.filter { $0.recordId == recordId }
    }

    /// 获取某条风险是否已被确认修改
    func isRiskConfirmed(riskId: String) -> Bool {
        revisions.contains { $0.riskId == riskId && $0.status == .confirmed }
    }

    /// 获取已确认修改的风险 ID 集合
    func confirmedRiskIDs(for recordId: UUID) -> Set<String> {
        let ids = revisions
            .filter { $0.recordId == recordId && $0.status == .confirmed }
            .compactMap(\.riskId)
        return Set(ids)
    }

    /// 保存一条修改记录（如已有同风险旧记录则更新）
    @discardableResult
    func saveRevision(
        recordId: UUID,
        riskId: String,
        beforeText: String,
        afterText: String
    ) -> LocalRevision {
        if let existing = fetchEntities().first(where: { $0.riskId == riskId && $0.recordId == recordId }) {
            existing.beforeText = beforeText
            existing.afterText = afterText
            existing.statusRaw = RevisionState.confirmed.rawValue
            existing.updatedAt = Date()
            saveContext()
            load()
            return existing.toLocalRevision()
        }

        let revision = LocalRevision(
            recordId: recordId,
            segmentId: riskId,
            riskId: riskId,
            beforeText: beforeText,
            afterText: afterText,
            status: .confirmed
        )
        context.insert(StoredRevision(revision: revision))
        saveContext()
        load()
        return revision
    }

    private func load() {
        revisions = fetchEntities().map { $0.toLocalRevision() }
    }

    private func fetchEntities() -> [StoredRevision] {
        do {
            return try context.fetch(FetchDescriptor<StoredRevision>())
        } catch {
            return []
        }
    }

    private func saveContext() {
        do {
            try context.save()
        } catch {
            // Silent fail — must not crash the app
        }
    }

    private static func makeContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: StoredRevision.self)
        } catch {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: StoredRevision.self, configurations: config)
        }
    }
}
