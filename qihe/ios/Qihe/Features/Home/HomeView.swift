import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var healthState: HealthState = .checking

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    connectionCard

                    VStack(spacing: 12) {
                        HomeEntryCard(
                            title: "合同审查",
                            subtitle: "上传或粘贴合同，查看原文、风险与主体。",
                            systemImage: "doc.text.magnifyingglass"
                        ) {
                            appState.path.append(.review(prefill: nil))
                        }

                        HomeEntryCard(
                            title: "合同生成",
                            subtitle: "说明交易安排，生成草案、待补充字段和签前清单。",
                            systemImage: "doc.text.fill"
                        ) {
                            appState.path.append(.generate(prefill: nil))
                        }
                    }

                    PaperCard {
                        VStack(spacing: 12) {
                            ProcessNode(
                                title: "本地历史",
                                detail: "记录只保存在本机，断网时也能打开。",
                                isActive: true
                            )
                            ProcessNode(
                                title: "文件范围",
                                detail: "仅支持 PDF、Word/DOCX、TXT。",
                                isDone: true
                            )
                        }
                    }
                }
                .padding(20)
            }
        }
        .qiheInlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .qiheTopTrailing) {
                Button {
                    appState.isHistoryPresented = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .foregroundStyle(QiheColor.navy)
                .accessibilityLabel("本地历史")
            }
        }
        .task {
            await checkHealth()
        }
        .refreshable {
            await checkHealth()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                SealMark(size: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("契合")
                        .font(QiheFont.title(size: 32))
                        .foregroundStyle(QiheColor.ink)

                    Text("文书 · 印鉴 × 法务藏青")
                        .font(QiheFont.caption(size: 13, weight: .semibold))
                        .foregroundStyle(QiheColor.seal)
                }
            }

            Text("合同审查与合同生成")
                .font(QiheFont.title(size: 26))
                .foregroundStyle(QiheColor.ink)

            Text("面向 iPhone 的 AI 合同助手。先完成合同材料，再进入审查或生成闭环。")
                .font(QiheFont.body(size: 15))
                .foregroundStyle(QiheColor.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 18)
    }

    private var connectionCard: some View {
        PaperCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: healthState.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(healthState.color)
                    .frame(width: 34, height: 34)
                    .background(healthState.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(healthState.title)
                        .font(QiheFont.body(size: 15, weight: .semibold))
                        .foregroundStyle(QiheColor.ink)

                    Text(healthState.detail(baseURL: appState.apiClient.baseURL))
                        .font(QiheFont.caption())
                        .foregroundStyle(QiheColor.muted)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Task {
                        await checkHealth()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .foregroundStyle(QiheColor.navy)
                .disabled(healthState == .checking)
            }
        }
    }

    private func checkHealth() async {
        healthState = .checking
        do {
            let response = try await appState.apiClient.health()
            healthState = response.status == "ok" ? .online(service: response.service) : .offline(message: "服务状态异常")
        } catch {
            healthState = .offline(message: error.localizedDescription)
        }
    }
}

private enum HealthState: Equatable {
    case checking
    case online(service: String)
    case offline(message: String)

    var title: String {
        switch self {
        case .checking:
            return "正在连接后端"
        case .online:
            return "后端已连接"
        case .offline:
            return "后端未连接"
        }
    }

    var iconName: String {
        switch self {
        case .checking:
            return "hourglass"
        case .online:
            return "checkmark.seal.fill"
        case .offline:
            return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .checking:
            return QiheColor.navy
        case .online:
            return QiheColor.pine
        case .offline:
            return QiheColor.seal
        }
    }

    var background: Color {
        switch self {
        case .checking:
            return QiheColor.navySoft
        case .online:
            return QiheColor.pineSoft
        case .offline:
            return QiheColor.sealSoft
        }
    }

    func detail(baseURL: URL) -> String {
        switch self {
        case .checking:
            return baseURL.absoluteString
        case let .online(service):
            return "\(service) · \(baseURL.absoluteString)"
        case let .offline(message):
            return "\(message) · \(baseURL.absoluteString)"
        }
    }
}
