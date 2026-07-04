import Foundation
import WebKit

final class LocalWebAppSchemeHandler: NSObject, WKURLSchemeHandler {
    private let webAppDirectory: URL?

    override init() {
        self.webAppDirectory = Bundle.main.resourceURL?.appendingPathComponent("WebApp", isDirectory: true)
        super.init()
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let requestURL = urlSchemeTask.request.url,
              let fileURL = resolveFileURL(for: requestURL),
              let data = try? Data(contentsOf: fileURL) else {
            sendNotFound(to: urlSchemeTask)
            return
        }

        let response = URLResponse(
            url: requestURL,
            mimeType: mimeType(for: fileURL.pathExtension),
            expectedContentLength: data.count,
            textEncodingName: textEncodingName(for: fileURL.pathExtension)
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private func resolveFileURL(for requestURL: URL) -> URL? {
        guard let webAppDirectory else { return nil }

        let rawPath = requestURL.path.removingPercentEncoding ?? requestURL.path
        let normalizedPath = rawPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relativePath = normalizedPath.isEmpty ? "index.html" : normalizedPath

        guard !relativePath.contains("..") else { return nil }

        let requestedFile = webAppDirectory.appendingPathComponent(relativePath, isDirectory: false)
        if FileManager.default.fileExists(atPath: requestedFile.path) {
            return requestedFile
        }

        if URL(fileURLWithPath: relativePath).pathExtension.isEmpty {
            return webAppDirectory.appendingPathComponent("index.html", isDirectory: false)
        }

        return nil
    }

    private func sendNotFound(to urlSchemeTask: WKURLSchemeTask) {
        let data = Data("Not found".utf8)
        let response = URLResponse(
            url: urlSchemeTask.request.url ?? URL(string: "qihe://localhost/404")!,
            mimeType: "text/plain",
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html":
            return "text/html"
        case "js", "mjs":
            return "application/javascript"
        case "css":
            return "text/css"
        case "json":
            return "application/json"
        case "svg":
            return "image/svg+xml"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "woff":
            return "font/woff"
        case "woff2":
            return "font/woff2"
        case "ttf":
            return "font/ttf"
        default:
            return "application/octet-stream"
        }
    }

    private func textEncodingName(for fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "html", "js", "mjs", "css", "json", "svg", "txt":
            return "utf-8"
        default:
            return nil
        }
    }
}
