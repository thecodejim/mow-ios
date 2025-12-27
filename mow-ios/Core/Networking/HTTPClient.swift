import Foundation

// MARK: - HTTP Client

struct HTTPClient: Sendable {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute<Response: Decodable>(_ request: HTTPRequest<Response>) async throws -> Response {
        let urlRequest = try request.buildURLRequest()
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.invalidCredentials
            }
            
            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(message: errorResponse.detail ?? "Unknown error")
            }
            
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }

        return try JSONDecoder().decode(Response.self, from: data)
    }

    func execute(_ request: HTTPRequest<Void>) async throws {
        let urlRequest = try request.buildURLRequest()

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw APIError.invalidCredentials
            }

            // Try to parse error response
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(message: errorResponse.detail ?? "Unknown error")
            }

            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }
}

// MARK: - HTTP Request

struct HTTPRequest<Response> {
    let endpoint: URL
    let method: HTTPMethod
    let headers: [String: String]
    let body: Data?

    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
        case patch = "PATCH"
    }

    init(
        endpoint: URL,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.endpoint = endpoint
        self.method = method
        self.headers = headers
        self.body = body
    }

    static func post<Body: Encodable>(
        endpoint: URL,
        body: Body
    ) throws -> HTTPRequest<Response> {
        let data = try JSONEncoder().encode(body)
        return HTTPRequest(
            endpoint: endpoint,
            method: .post,
            headers: [
                "Content-Type": "application/json",
                "Accept": "application/json"
            ],
            body: data
        )
    }

    func buildURLRequest() throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = method.rawValue
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        request.httpBody = body

        return request
    }
}

// MARK: - Error Response DTO

struct ErrorResponse: Codable {
    let detail: String?
}
