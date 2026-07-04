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
}
