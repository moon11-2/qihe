import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var isHistoryPresented = false

    let apiClient: APIClient

    init(apiClient: APIClient = .local) {
        self.apiClient = apiClient
    }

    func resetToHome() {
        path.removeAll()
    }

    func openHistoryRecord(_ record: HistoryRecord) {
        isHistoryPresented = false
        switch record.type {
        case .chat:
            path.append(.chat(localRecordId: record.id))
        case .review:
            path.append(.reviewResult(recordId: record.id))
        case .generate:
            path.append(.generateResult(recordId: record.id))
        }
    }
}
