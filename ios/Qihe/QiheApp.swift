import SwiftUI

@main
struct QiheApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var authStore = AuthStore()
    @StateObject private var revisionStore = RevisionStore()
    @StateObject private var jobPollingStore = JobPollingStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(historyStore)
                .environmentObject(authStore)
                .environmentObject(revisionStore)
                .environmentObject(jobPollingStore)
                .onAppear {
                    // 任务三：注入 APIClient 到 RevisionStore 以支持后端同步
                    revisionStore.apiClient = appState.apiClient
                    // 任务四：注入依赖到 JobPollingStore
                    jobPollingStore.apiClient = appState.apiClient
                    jobPollingStore.historyStore = historyStore
                }
        }
    }
}
