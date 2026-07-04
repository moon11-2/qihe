import Foundation
import UniformTypeIdentifiers

struct APIClient {
    var baseURL: URL
    var session: URLSession = .shared

    static var local: APIClient {
        APIClient(baseURL: AppEnvironment.apiBaseURL)
    }

    func health() async throws -> HealthResponse {
        try await send(path: "api/health", method: "GET")
    }

    func chat(messages: [ChatMessage]) async throws -> ChatResponse {
        let apiMessages = messages.map { ChatAPIMessage(role: $0.role, content: $0.content) }
        return try await send(
            path: "api/chat",
            method: "POST",
            body: ChatRequest(messages: apiMessages)
        )
    }

    func uploadFile(from fileURL: URL) async throws -> UploadedFile {
        try QiheDocumentValidator.validate(fileURL)

        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let fileData = try Data(contentsOf: fileURL)
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url(for: "api/files/upload"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            boundary: boundary,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            contentType: QiheDocumentValidator.contentType(for: fileURL),
            data: fileData
        )

        let response: FileUploadResponse = try await data(for: request)
        return UploadedFile(
            fileId: response.fileId,
            filename: response.filename,
            contentType: response.contentType,
            status: response.status
        )
    }

    func runReview(text: String?, file: UploadedFile?) async throws -> ReviewResult {
        let request = ContractRunRequest(
            mode: .review,
            text: text?.trimmedForInput.nilIfBlank,
            fileId: file?.fileId,
            metadata: metadata(for: file)
        )
        let response: ContractRunResponse<ReviewResult> = try await send(
            path: "api/contracts/run",
            method: "POST",
            body: request
        )
        return response.result
    }

    func runGenerate(text: String?, file: UploadedFile?) async throws -> GenerateResult {
        let request = ContractRunRequest(
            mode: .generate,
            text: text?.trimmedForInput.nilIfBlank,
            fileId: file?.fileId,
            metadata: metadata(for: file)
        )
        let response: ContractRunResponse<GenerateResult> = try await send(
            path: "api/contracts/run",
            method: "POST",
            body: request
        )
        return response.result
    }

    func exportReviewWord(title: String, payload: ReviewResult) async throws -> URL {
        try await exportWord(type: .review, title: title, payload: payload)
    }

    func exportGenerateWord(title: String, payload: GenerateResult) async throws -> URL {
        try await exportWord(type: .generate, title: title, payload: payload)
    }

    private func exportWord<Payload: Codable & Hashable>(
        type: ContractMode,
        title: String,
        payload: Payload
    ) async throws -> URL {
        let requestBody = ContractExportRequest(type: type, title: title, payload: payload)
        var request = URLRequest(url: url(for: "api/contracts/export/word"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: "\(title.sanitizedFilename).docx")
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    private func send<Response: Decodable>(
        path: String,
        method: String
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        return try await data(for: request)
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await data(for: request)
    }

    private func data<Response: Decodable>(for request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(Response.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(APIErrorResponse.self, from: data).displayString)
                ?? String(data: data, encoding: .utf8)
                ?? "请求失败"
            throw APIClientError.server(statusCode: httpResponse.statusCode, detail: message)
        }
    }

    private func url(for path: String) -> URL {
        baseURL.appending(path: path)
    }

    private func multipartBody(
        boundary: String,
        fieldName: String,
        filename: String,
        contentType: String,
        data: Data
    ) -> Data {
        var body = Data()
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(contentType)\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        return body
    }

    private func metadata(for file: UploadedFile?) -> [String: JSONValue] {
        guard let file else {
            return [:]
        }
        return [
            "filename": .string(file.filename),
            "content_type": .string(file.contentType ?? "application/octet-stream")
        ]
    }

    private var encoder: JSONEncoder {
        Self.encoder
    }

    private var decoder: JSONDecoder {
        Self.decoder
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
}

struct HealthResponse: Decodable, Hashable {
    let status: String
    let service: String
}

private struct FileUploadResponse: Decodable {
    let fileId: String
    let filename: String
    let contentType: String?
    let status: String
}

private struct APIErrorResponse: Decodable {
    let error: APIErrorDetail?
    let detail: JSONValue?

    var displayString: String {
        if let error {
            return error.message
        }
        return detail?.displayString ?? "请求失败"
    }
}

private struct APIErrorDetail: Decodable {
    let code: String
    let message: String
}

enum APIClientError: LocalizedError {
    case unsupportedFileType
    case server(statusCode: Int, detail: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "仅支持 PDF、Word/DOCX 和 TXT 文件。"
        case let .server(statusCode, detail):
            return "请求失败（\(statusCode)）：\(detail)"
        }
    }
}

enum QiheDocumentValidator {
    static let allowedExtensions: Set<String> = ["pdf", "docx", "txt"]
    static let allowedTypes: [UTType] = [
        .pdf,
        .plainText,
        UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
    ]

    static func validate(_ url: URL) throws {
        guard allowedExtensions.contains(url.pathExtension.lowercased()) else {
            throw APIClientError.unsupportedFileType
        }
    }

    static func contentType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
        }
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}

private extension String {
    var sanitizedFilename: String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_")
        let value = unicodeScalars
            .map { allowed.contains($0) ? String($0) : "-" }
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return value.isEmpty ? "qihe-export" : value
    }
}
