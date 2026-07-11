import SwiftUI
#if os(iOS)
import UIKit
#endif

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    init() {
        #if os(iOS)
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.82)
        appearance.shadowColor = UIColor(red: 10 / 255, green: 27 / 255, blue: 82 / 255, alpha: 0.08)

        let selected = UIColor(red: 31 / 255, green: 110 / 255, blue: 245 / 255, alpha: 1)
        let unselected = UIColor(red: 176 / 255, green: 196 / 255, blue: 232 / 255, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = selected
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
        appearance.stackedLayoutAppearance.normal.iconColor = unselected
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
        appearance.inlineLayoutAppearance = appearance.stackedLayoutAppearance
        appearance.compactInlineLayoutAppearance = appearance.stackedLayoutAppearance

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selected
        UITabBar.appearance().unselectedItemTintColor = unselected
        #endif
    }

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            NavigationStack(path: $appState.path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route)
                    }
            }
            .tabItem {
                Label("首页", systemImage: appState.selectedTab == .home ? "house.fill" : "house")
            }
            .tag(RootTab.home)

            HistoryView()
                .tabItem {
                    Label("历史", systemImage: appState.selectedTab == .history ? "clock.fill" : "clock")
                }
                .tag(RootTab.history)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("我的", systemImage: appState.selectedTab == .profile ? "person.crop.circle.fill" : "person.crop.circle")
            }
            .tag(RootTab.profile)
        }
        .tint(QiheColor.brandBlue)
        #if os(iOS)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        #endif
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case let .chat(localRecordId, initialMessage):
            ChatView(localRecordId: localRecordId, initialMessage: initialMessage)
        case let .review(prefill, attachment):
            ReviewInputView(prefill: prefill, initialAttachment: attachment)
        case let .generate(prefill, sourceChatRecordId):
            GenerateInputView(prefill: prefill, sourceChatRecordId: sourceChatRecordId)
        case let .reviewResult(recordId):
            ReviewResultView(recordId: recordId)
        case let .subject(recordId):
            SubjectView(recordId: recordId)
        case let .generateResult(recordId):
            GenerateResultView(recordId: recordId)
        case let .progress(jobId, mode, requestText, attachment, sourceChatRecordId):
            ContractProgressView(
                jobId: jobId,
                mode: mode,
                requestText: requestText,
                attachment: attachment,
                sourceChatRecordId: sourceChatRecordId
            )
        }
    }
}
