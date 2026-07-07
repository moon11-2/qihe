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

/// 修改记录本地存储管理器。
///
/// 任务三升级：从"纯本地存储"变为"后端优先、本地缓存"模式。
/// - 后端返回 revisions 时，以它们为准并缓存到本地
/// - 用户新增修改时，同步到后端并缓存到本地
/// - 历史恢复时，优先从后端拉取，本地缓存作为离线回退
@MainActor
final class RevisionStore: ObservableObject {
    @Published private(set) var revisions: [LocalRevision] = []

    private let container: ModelContainer
    private let context: ModelContext

    /// 后端 revision 是否已同步过的记录 ID 集合
    private var syncedRecordIDs: Set<UUID> = []

    /// 用于后端同步的 API client（外部注入）
    var apiClient: APIClient?

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

    /// 获取已确认修改的 block ID → RevisionState 映射（用于恢复历史状态）
    func confirmedBlockStates(for recordId: UUID) -> [String: RevisionState] {
        var states: [String: RevisionState] = [:]
        for revision in revisions where revision.recordId == recordId && revision.status == .confirmed {
            // segmentId 即为 blockId（或 riskId）
            let blockId = revision.segmentId
            states[blockId] = .confirmed
        }
        return states
    }

    /// 保存一条修改记录（如已有同风险旧记录则更新）
    @discardableResult
    func saveRevision(
        recordId: UUID,
        riskId: String,
        beforeText: String,
        afterText: String,
        syncToBackend: Bool = true
    ) -> LocalRevision {
        let localRevision: LocalRevision

        if let existing = fetchEntities().first(where: { $0.riskId == riskId && $0.recordId == recordId }) {
            existing.beforeText = beforeText
            existing.afterText = afterText
            existing.statusRaw = RevisionState.confirmed.rawValue
            existing.updatedAt = Date()
            saveContext()
            load()
            localRevision = existing.toLocalRevision()
        } else {
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
            localRevision = revision
        }

        // 任务三：同步到后端
        if syncToBackend, let apiClient {
            let contractRevision = ContractRevision(
                id: localRevision.id.uuidString,
                riskId: riskId,
                beforeText: beforeText,
                afterText: afterText,
                status: .confirmed
            )
            Task {
                _ = try? await apiClient.syncRevision(
                    recordId: recordId,
                    revision: contractRevision
                )
            }
        }

        return localRevision
    }

    // MARK: - 后端同步（任务三）

    /// 从后端拉取 revisions 并合并到本地缓存
    /// - Parameter recordId: 历史记录 ID
    /// - Returns: 合并后的修订列表
    func fetchAndMergeRevisions(recordId: UUID) async -> [LocalRevision] {
        guard let apiClient, !syncedRecordIDs.contains(recordId) else {
            return revisions(for: recordId)
        }

        do {
            let backendRevisions = try await apiClient.fetchRevisions(recordId: recordId)
            mergeBackendRevisions(recordId: recordId, backendRevisions: backendRevisions)
            syncedRecordIDs.insert(recordId)
            return revisions(for: recordId)
        } catch {
            // 后端不可用时回退本地缓存
            return revisions(for: recordId)
        }
    }

    /// 将后端 revisions 批量合并到本地缓存
    func mergeBackendRevisions(recordId: UUID, backendRevisions: [ContractRevision]) {
        guard !backendRevisions.isEmpty else { return }

        let localEntities = fetchEntities().filter { $0.recordId == recordId }
        var localByRiskID: [String: StoredRevision] = [:]
        for entity in localEntities {
            if let riskId = entity.riskId {
                localByRiskID[riskId] = entity
            }
        }

        for backendRev in backendRevisions {
            let riskId = backendRev.riskId ?? backendRev.blockId ?? backendRev.id

            if let existing = localByRiskID[riskId] {
                // 以后端数据更新本地
                existing.beforeText = backendRev.beforeText
                existing.afterText = backendRev.afterText
                existing.statusRaw = backendRev.status.rawValue
                existing.updatedAt = backendRev.createdAt ?? Date()
            } else {
                let localRev = backendRev.toLocalRevision(recordId: recordId)
                context.insert(StoredRevision(revision: localRev))
            }
        }

        saveContext()
        load()
    }

    /// 标记记录已同步（无需再次拉取）
    func markSynced(recordId: UUID) {
        syncedRecordIDs.insert(recordId)
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
