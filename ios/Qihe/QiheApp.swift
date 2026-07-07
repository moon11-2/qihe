import SwiftUI

@main
struct QiheApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var revisionStore = RevisionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(historyStore)
                .environmentObject(authStore)
                .environmentObject(revisionStore)
                .onAppear {
                    // 任务三：注入 APIClient 到 RevisionStore 以支持后端同步
                    revisionStore.apiClient = appState.apiClient
                }
        }
    }
}
