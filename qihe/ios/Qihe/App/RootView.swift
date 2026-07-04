import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack(path: $appState.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .chat:
                        ChatView()
                    case let .review(prefill):
                        ReviewInputView(prefill: prefill)
                    case let .generate(prefill):
                        GenerateInputView(prefill: prefill)
                    case let .reviewResult(recordId):
                        ReviewResultView(recordId: recordId)
                    case let .generateResult(recordId):
                        GenerateResultView(recordId: recordId)
                    }
                }
                .sheet(isPresented: $appState.isHistoryPresented) {
                    HistoryView()
                }
        }
    }
}

