import Foundation

// MARK: - Live API Service

struct LiveAPIService: APIService {
    private let baseURL: URL
    private let session: URLSession
    
    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }
    
    func login(email: String, password: String) async throws -> AuthSession {
        let endpoint = baseURL.appendingPathComponent("auth/jwt/create/")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let requestBody = LoginRequest(username: email, password: password)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
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
        
        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        
        // Extract display name from email (username)
        let displayName = email.components(separatedBy: "@").first ?? "Volunteer"
        
        return AuthSession(
            token: loginResponse.access,
            displayName: displayName
        )
    }
    
    func sendPasswordReset(email: String) async throws {
        // TODO: Implement when API endpoint is available
        // For now, use mock implementation
        try await Task.sleep(nanoseconds: 600_000_000)
        
        if email.isEmpty {
            throw APIError.invalidCredentials
        }
    }
    
    func fetchHomeSnapshot() async throws -> HomeSnapshot {
        // TODO: Implement when API endpoint is available
        // For now, use mock implementation
        try await Task.sleep(nanoseconds: 800_000_000)
        
        return HomeSnapshot(
            headline: "You have 12 meals and 4 routes today.",
            stats: [
                .init(label: "Families Served", value: "32", trend: "+4 vs yesterday"),
                .init(label: "Miles", value: "18.4", trend: "On track"),
                .init(label: "Volunteer Hours", value: "6h 15m", trend: "Ahead of plan")
            ],
            meals: [
                .init(title: "Low-sodium chicken bowl", calories: 540, deliveryTime: .now.addingTimeInterval(1_800)),
                .init(title: "Gluten-free pasta", calories: 610, deliveryTime: .now.addingTimeInterval(3_600)),
                .init(title: "Fresh salad kit", calories: 320, deliveryTime: .now.addingTimeInterval(7_200))
            ],
            deliveries: [
                .init(recipient: "The Johnson Family", address: "18 W 34th St", distanceMiles: 1.3),
                .init(recipient: "Ms. Chen", address: "44 Spring Ave", distanceMiles: 2.1),
                .init(recipient: "The Rivera Household", address: "220 Beacon Rd", distanceMiles: 4.8)
            ],
            profile: .init(name: "Taylor West", role: "Lead Volunteer", territory: "North Austin")
        )
    }
}

// MARK: - DTOs

extension LiveAPIService {
    struct LoginRequest: Codable {
        let username: String
        let password: String
    }
    
    struct LoginResponse: Codable {
        let access: String
        let refresh: String
    }
    
    struct ErrorResponse: Codable {
        let detail: String?
    }
}

// MARK: - Errors

enum APIError: Error, LocalizedError, Equatable {
    case invalidResponse
    case invalidCredentials
    case serverError(message: String)
    case httpError(statusCode: Int)
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server response was invalid. Please try again."
        case .invalidCredentials:
            return "That email and password combo does not look right."
        case .serverError(let message):
            return message
        case .httpError(let statusCode):
            return "Server error: \(statusCode). Please try again later."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse):
            return true
        case (.invalidCredentials, .invalidCredentials):
            return true
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.httpError(let lhsCode), .httpError(let rhsCode)):
            return lhsCode == rhsCode
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}
