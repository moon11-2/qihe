import Foundation

enum AppRoute: Hashable {
    case chat(localRecordId: UUID?)
    case review(prefill: String?)
    case generate(prefill: String?)
    case reviewResult(recordId: UUID)
    case generateResult(recordId: UUID)
}

