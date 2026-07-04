import Foundation

final class AppState: ObservableObject {
    @Published var path: [AppRoute] = []
    @Published var isHistoryPresented = false

    func resetToHome() {
        path.removeAll()
    }
}

