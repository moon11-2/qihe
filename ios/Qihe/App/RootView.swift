import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack(path: $appState.path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem {
                Label("首页", systemImage: "house")
            }
            .tag(RootTab.home)

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: "clock.arrow.circlepath")
                }
                .tag(RootTab.history)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("我的", systemImage: "person.crop.circle")
            }
            .tag(RootTab.profile)
        }
        .tint(QiheColor.navy)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case let .chat(localRecordId, initialMessage):
            ChatView(localRecordId: localRecordId, initialMessage: initialMessage)
        case let .review(prefill, attachment):
            ReviewInputView(prefill: prefill, initialAttachment: attachment)
        case let .generate(prefill):
            GenerateInputView(prefill: prefill)
        case let .reviewResult(recordId):
            ReviewResultView(recordId: recordId)
        case let .subject(recordId):
            SubjectView(recordId: recordId)
        case let .generateResult(recordId):
            GenerateResultView(recordId: recordId)
        }
    }
}
