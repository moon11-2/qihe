import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack(path: $appState.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
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
                .sheet(isPresented: $appState.isHistoryPresented) {
                    HistoryView()
                        .environmentObject(appState)
                        .qiheHistorySheetPresentation()
                }
        }
    }
}
