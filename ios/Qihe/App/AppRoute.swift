import Foundation

enum AppRoute: Hashable {
    case chat(localRecordId: UUID?, initialMessage: String? = nil)
    case review(prefill: String?, attachment: UploadedFile? = nil)
    case generate(prefill: String?, sourceChatRecordId: UUID? = nil)
    case reviewResult(recordId: UUID)
    case subject(recordId: UUID)
    case generateResult(recordId: UUID)
    /// 任务四：进度页路由
    case progress(
        jobId: String,
        mode: ContractMode,
        requestText: String? = nil,
        attachment: UploadedFile? = nil,
        sourceChatRecordId: UUID? = nil
    )
}
