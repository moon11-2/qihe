import Foundation
import UniformTypeIdentifiers

struct APIClient {
    var baseURL: URL
    var session: URLSession = .shared

    static var local: APIClient {
        APIClient(baseURL: AppEnvironment.apiBaseURL)
    }

    func health() async throws -> HealthResponse {
        try await send(path: "api/health", method: "GET", requiresAuth: false)
    }

    func register(email: String, password: String, displayName: String?) async throws -> AuthSession {
        let response: AuthTokenAPIResponse = try await send(
            path: "api/auth/register",
            method: "POST",
            body: AuthRegisterRequest(email: email, password: password, displayName: displayName),
            requiresAuth: false
        )
        return response.session
    }

    func login(email: String, password: String) async throws -> AuthSession {
        let response: AuthTokenAPIResponse = try await send(
            path: "api/auth/login",
            method: "POST",
            body: AuthLoginRequest(email: email, password: password),
            requiresAuth: false
        )
        return response.session
    }

    func me() async throws -> AuthUser {
        let response: AuthAPIUser = try await send(path: "api/auth/me", method: "GET")
        return response.user
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
        var request = request(for: "api/files/upload", method: "POST")
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

    func runReview(
        text: String?,
        file: UploadedFile?,
        metadata structuredMetadata: [String: JSONValue] = [:]
    ) async throws -> ReviewResult {
        let request = ContractRunRequest(
            mode: .review,
            text: text?.trimmedForInput.nilIfBlank,
            fileId: file?.fileId,
            metadata: metadata(for: file, merging: structuredMetadata)
        )
        let response: ContractRunResponse<ReviewResult> = try await send(
            path: "api/contracts/run",
            method: "POST",
            body: request
        )
        return response.result
    }

    func runGenerate(
        text: String?,
        file: UploadedFile?,
        metadata structuredMetadata: [String: JSONValue] = [:]
    ) async throws -> GenerateResult {
        let request = ContractRunRequest(
            mode: .generate,
            text: text?.trimmedForInput.nilIfBlank,
            fileId: file?.fileId,
            metadata: metadata(for: file, merging: structuredMetadata)
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
        var request = request(for: "api/contracts/export/word", method: "POST")
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
        method: String,
        requiresAuth: Bool = true
    ) async throws -> Response {
        let request = request(for: path, method: method, requiresAuth: requiresAuth)
        return try await data(for: request)
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        requiresAuth: Bool = true
    ) async throws -> Response {
        var request = request(for: path, method: method, requiresAuth: requiresAuth)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await data(for: request)
    }

    private func request(for path: String, method: String, requiresAuth: Bool = true) -> URLRequest {
        var request = URLRequest(url: url(for: path))
        request.httpMethod = method
        if requiresAuth, let token = AuthSessionStorage.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func data<Response: Decodable>(for request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIClientError.invalidResponse
        }
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

    private func metadata(
        for file: UploadedFile?,
        merging extraMetadata: [String: JSONValue] = [:]
    ) -> [String: JSONValue] {
        var metadata = extraMetadata
        guard let file else {
            return metadata
        }
        metadata["filename"] = .string(file.filename)
        metadata["content_type"] = .string(file.contentType ?? "application/octet-stream")
        return metadata
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

private struct AuthRegisterRequest: Encodable {
    let email: String
    let password: String
    let displayName: String?
}

private struct AuthLoginRequest: Encodable {
    let email: String
    let password: String
}

private struct AuthTokenAPIResponse: Decodable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let user: AuthAPIUser

    var session: AuthSession {
        AuthSession(
            accessToken: accessToken,
            tokenType: tokenType,
            expiresIn: expiresIn,
            user: user.user
        )
    }
}

private struct AuthAPIUser: Decodable {
    let id: Int
    let email: String
    let displayName: String?

    var user: AuthUser {
        AuthUser(
            id: String(id),
            displayName: displayName?.nilIfBlank ?? email,
            account: email
        )
    }
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
            if error.code == "auth_required" {
                return "请登录后使用"
            }
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
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "仅支持 PDF、Word/DOCX 和 TXT 文件。"
        case let .server(statusCode, detail):
            if statusCode == 401 {
                return detail
            }
            return "服务器返回异常（\(statusCode)）：\(detail)"
        case .invalidResponse:
            return "服务器返回异常"
        }
    }
}

extension Error {
    var qiheDisplayMessage: String {
        if let urlError = self as? URLError {
            switch urlError.code {
            case .timedOut:
                return "请求超时"
            case .cannotConnectToHost,
                 .cannotFindHost,
                 .dnsLookupFailed,
                 .networkConnectionLost,
                 .notConnectedToInternet:
                return "无法连接服务器"
            case .badServerResponse:
                return "服务器返回异常"
            case .cancelled:
                return "请求已取消"
            default:
                return "请求失败，请稍后重试"
            }
        }

        if self is DecodingError {
            return "服务器返回异常"
        }

        return localizedDescription.nilIfBlank ?? "请求失败，请稍后重试"
    }
}

enum QiheDocumentValidator {
    static let allowedExtensions: Set<String> = ["pdf", "doc", "docx", "txt"]
    static let allowedTypes: [UTType] = [
        .pdf,
        .plainText,
        UTType(importedAs: "com.microsoft.word.doc"),
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
        case "doc":
            return "application/msword"
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
