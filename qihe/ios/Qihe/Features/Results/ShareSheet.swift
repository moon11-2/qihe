import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ShareDocument: Identifiable {
    let id = UUID()
    let url: URL
}

#if canImport(UIKit)
struct ShareSheet: UIViewControllerRepresentable {
    let document: ShareDocument

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [document.url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
    }
}
#else
struct ShareSheet: View {
    let document: ShareDocument

    var body: some View {
        VStack(spacing: 12) {
            Text("Word 文件已生成")
                .font(QiheFont.body(size: 16, weight: .semibold))
                .foregroundStyle(QiheColor.ink)

            Text(document.url.path)
                .font(QiheFont.caption())
                .foregroundStyle(QiheColor.muted)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)
        }
        .padding(24)
        .frame(minWidth: 320, minHeight: 160)
    }
}
#endif
