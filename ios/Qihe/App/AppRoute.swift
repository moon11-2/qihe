import Foundation

enum AppRoute: Hashable {
    case chat(localRecordId: UUID?, initialMessage: String? = nil)
    case review(prefill: String?, attachment: UploadedFile? = nil)
    case generate(prefill: String?)
    case reviewResult(recordId: UUID)
    case subject(recordId: UUID)
    case generateResult(recordId: UUID)
}
