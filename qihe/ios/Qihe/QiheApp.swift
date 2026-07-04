import SwiftUI

@main
struct QiheApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var historyStore = HistoryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(historyStore)
        }
    }
}
