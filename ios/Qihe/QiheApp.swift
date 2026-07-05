import SwiftUI

@main
struct QiheApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(historyStore)
                .environmentObject(authStore)
        }
    }
}
