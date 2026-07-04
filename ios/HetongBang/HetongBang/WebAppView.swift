import SwiftUI
import WebKit

struct WebAppView: UIViewRepresentable {
    private static let localScheme = "qihe"

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(LocalWebAppSchemeHandler(), forURLScheme: Self.localScheme)
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.backgroundColor = UIColor(red: 0.969, green: 0.973, blue: 0.984, alpha: 1.0)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        loadBundledWebApp(in: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    private func loadBundledWebApp(in webView: WKWebView) {
        guard Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "WebApp") != nil,
              let appURL = URL(string: "\(Self.localScheme)://localhost/index.html") else {
            let html = """
            <!doctype html>
            <html>
            <body style="font-family:-apple-system;padding:24px;">
            <h2>契合资源未找到</h2>
            <p>请重新运行 npm run build:h5 并确认 WebApp/index.html 已复制到 iOS 工程。</p>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: nil)
            return
        }

        webView.load(URLRequest(url: appURL))
    }
}
