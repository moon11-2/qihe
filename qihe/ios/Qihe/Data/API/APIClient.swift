import Foundation

struct APIClient {
    var baseURL: URL

    static let local = APIClient(baseURL: AppEnvironment.apiBaseURL)

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }

    func health() async throws -> HealthResponse {
        let url = baseURL.appending(path: "/api/health")
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try decoder.decode(HealthResponse.self, from: data)
    }

    func chat(messages: [ChatMessage]) async throws -> ChatResponse {
        try await postJSON(path: "/api/chat", body: ChatRequest(messages: messages))
    }

    func runContract(_ request: ContractRunRequest) async throws -> ContractRunResponse {
        try await postJSON(path: "/api/contracts/run", body: request)
    }

    func uploadFile(fileURL: URL) async throws -> FileUploadResponse {
        let filename = fileURL.lastPathComponent
        guard let mimeType = Self.mimeType(for: filename) else {
            throw APIClientError.invalidFileType("仅支持 PDF、DOCX、TXT 文件")
        }
        let data = try Data(contentsOf: fileURL)
        return try await uploadFile(data: data, filename: filename, mimeType: mimeType)
    }

    func uploadFile(data: Data, filename: String, mimeType: String) async throws -> FileUploadResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = baseURL.appending(path: "/api/files/upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(data: data, filename: filename, mimeType: mimeType, boundary: boundary)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: responseData)
        return try decoder.decode(FileUploadResponse.self, from: responseData)
    }

    func exportReviewWord(title: String, result: ReviewResult) async throws -> Data {
        try await exportWord(type: "review_result", title: title, payload: result)
    }

    func exportGenerateWord(title: String, result: GenerateResult) async throws -> Data {
        try await exportWord(type: "generate_result", title: title, payload: result)
    }

    private func postJSON<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(ResponseBody.self, from: data)
    }

    private func exportWord<Payload: Encodable>(type: String, title: String, payload: Payload) async throws -> Data {
        let request = ContractExportRequest(type: type, title: title, payload: payload)
        return try await postRaw(path: "/api/contracts/export/word", body: request)
    }

    private func postRaw<RequestBody: Encodable>(path: String, body: RequestBody) async throws -> Data {
        let url = baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIClientError.invalidResponse
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            if let backendError = try? decoder.decode(BackendErrorResponse.self, from: data) {
                throw APIClientError.backend(
                    code: backendError.error.code,
                    message: backendError.error.message,
                    statusCode: httpResponse.statusCode
                )
            }
            throw APIClientError.httpStatus(httpResponse.statusCode)
        }
    }

    private func multipartBody(data: Data, filename: String, mimeType: String, boundary: String) -> Data {
        var body = Data()
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendString("\r\n--\(boundary)--\r\n")
        return body
    }

    static func mimeType(for filename: String) -> String? {
        switch (filename as NSString).pathExtension.lowercased() {
        case "pdf":
            return "application/pdf"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "txt":
            return "text/plain"
        default:
            return nil
        }
    }
}

enum APIClientError: LocalizedError, Equatable {
    case backend(code: String, message: String, statusCode: Int)
    case httpStatus(Int)
    case invalidFileType(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case let .backend(_, message, _):
            return message
        case let .httpStatus(statusCode):
            return "请求失败，状态码 \(statusCode)"
        case let .invalidFileType(message):
            return message
        case .invalidResponse:
            return "服务器响应格式不正确"
        }
    }
}

private struct ContractExportRequest<Payload: Encodable>: Encodable {
    let type: String
    let title: String
    let payload: Payload
}

private extension Data {
    mutating func appendString(_ value: String) {
        append(Data(value.utf8))
    }
}
