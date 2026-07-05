import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var isHistoryPresented = false
    @Published var selectedTab: RootTab = .home

    let apiClient: APIClient

    init(apiClient: APIClient = .local) {
        self.apiClient = apiClient
    }

    func resetToHome() {
        selectedTab = .home
        path.removeAll()
    }

    func openHistoryRecord(_ record: HistoryRecord) {
        isHistoryPresented = false
        selectedTab = .home
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

enum RootTab: Hashable {
    case home
    case history
    case profile
}
