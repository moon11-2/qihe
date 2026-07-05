import Foundation

enum AppEnvironment {
    static var apiBaseURL: URL {
        if let value = ProcessInfo.processInfo.environment["QIHE_API_BASE_URL"],
           let url = url(from: value) {
            return url
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: "QIHE_API_BASE_URL") as? String,
           let url = url(from: value) {
            return url
        }

        return URL(string: defaultAPIBaseURLString)!
    }

    static let defaultAPIBaseURLString = "https://api.qihe1.xyz"

    private static func url(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return URL(string: trimmed)
    }
}
