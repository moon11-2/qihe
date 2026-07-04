import SwiftUI

struct ReviewResultView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var historyStore: HistoryStore
    let recordId: UUID
    @State private var exportURL: URL?
    @State private var isExporting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            QiheColor.paper.ignoresSafeArea()

            if let result = historyStore.record(id: recordId)?.reviewResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(result.title)
                                .font(QiheFont.title(size: 24))
                            Spacer()
                            Text(result.riskLevel)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(riskColor(result.riskLevel))
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("原文")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(result.source.textPreview.isEmpty ? "无原文预览" : result.source.textPreview)
                                    .font(.system(size: 14))
                                    .foregroundStyle(QiheColor.inkSoft)
                            }
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("主体")
                                    .font(.system(size: 16, weight: .semibold))
                                PartyRow(label: "甲方", value: result.parties.partyA)
                                PartyRow(label: "乙方", value: result.parties.partyB)
                                PartyRow(label: "金额", value: result.parties.amount)
                                PartyRow(label: "期限", value: result.parties.term)
                                PartyRow(label: "合同类型", value: result.parties.contractType)
                                PartyRow(label: "司法辖区", value: result.parties.jurisdiction)
                            }
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("风险")
                                    .font(.system(size: 16, weight: .semibold))
                                ForEach(result.riskItems.isEmpty ? result.clauseReviews : result.riskItems) { item in
                                    RiskItemView(item: item)
                                }
                            }
                        }

                        PaperCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("审查依据")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(result.reviewBasis)
                                    .font(.system(size: 14))
                                    .foregroundStyle(QiheColor.inkSoft)
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundStyle(QiheColor.seal)
                        }

                        HStack {
                            Button {
                                Task {
                                    await export(result)
                                }
                            } label: {
                                Label(isExporting ? "导出中" : "导出 Word", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isExporting)

                            if let exportURL {
                                ShareLink(item: exportURL) {
                                    Label("分享", systemImage: "doc")
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            } else {
                Text("未找到本地审查记录")
                    .foregroundStyle(QiheColor.muted)
            }
        }
    }

    private func export(_ result: ReviewResult) async {
        errorMessage = nil
        isExporting = true
        do {
            let data = try await appState.apiClient.exportReviewWord(title: result.title, result: result)
            exportURL = try writeExport(data: data, title: result.title)
        } catch {
            errorMessage = error.localizedDescription
        }
        isExporting = false
    }

    private func riskColor(_ level: String) -> Color {
        switch level {
        case "高风险":
            return QiheColor.seal
        case "中风险":
            return QiheColor.amber
        case "低风险":
            return QiheColor.pine
        default:
            return QiheColor.muted
        }
    }
}

private struct PartyRow: View {
    let label: String
    let value: String?

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(QiheColor.muted)
                .frame(width: 72, alignment: .leading)
            Text((value?.isEmpty == false ? value : "待确认") ?? "待确认")
                .font(.system(size: 14))
                .foregroundStyle(QiheColor.ink)
            Spacer()
        }
    }
}

private struct RiskItemView: View {
    let item: ClauseReview

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.riskTitle)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(item.riskLevel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(item.riskLevel == "高风险" ? QiheColor.seal : QiheColor.amber)
            }
            if let clause = item.clause {
                Text("涉及条款：\(clause)")
                    .font(.system(size: 13))
                    .foregroundStyle(QiheColor.inkSoft)
            }
            Text(item.riskAnalysis)
                .font(.system(size: 14))
            Text("修订建议：\(item.revisionSuggestion)")
                .font(.system(size: 14))
                .foregroundStyle(QiheColor.inkSoft)
            if let replacement = item.suggestedReplacement {
                Text("建议替换：\(replacement)")
                    .font(.system(size: 14))
                    .foregroundStyle(QiheColor.inkSoft)
            }
            if !item.legalBasis.isEmpty {
                Text("法条依据：\(item.legalBasis.joined(separator: "；"))")
                    .font(.system(size: 13))
                    .foregroundStyle(QiheColor.muted)
            }
        }
        .padding(.vertical, 6)
    }
}

private func writeExport(data: Data, title: String) throws -> URL {
    let safeTitle = title.replacingOccurrences(of: "/", with: "-")
    let url = FileManager.default.temporaryDirectory.appending(path: "\(safeTitle).docx")
    try data.write(to: url, options: .atomic)
    return url
}
