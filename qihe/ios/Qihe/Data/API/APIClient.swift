import Foundation

struct APIClient {
    var baseURL: URL

    func health() async throws -> HealthResponse {
        let url = baseURL.appending(path: "/api/health")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }
}

struct HealthResponse: Decodable {
    let status: String
    let service: String
}

