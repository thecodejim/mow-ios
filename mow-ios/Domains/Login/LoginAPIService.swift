import Foundation

// MARK: - Login API Service Protocol

protocol LoginAPIService: Sendable {
    func login(email: String, password: String) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
}

// MARK: - Live Implementation

struct LiveLoginAPIService: LoginAPIService {
    private let baseURL: URL
    private let client: HTTPClient
    
    init(baseURL: URL, client: HTTPClient) {
        self.baseURL = baseURL
        self.client = client
    }
    
    func login(email: String, password: String) async throws -> AuthSession {
        let endpoint = baseURL.appendingPathComponent("auth/jwt/create/")
        let requestBody = LoginRequest(username: email, password: password)
        
        let request: HTTPRequest<LoginResponse> = try .post(
            endpoint: endpoint,
            body: requestBody
        )
        
        let response = try await client.execute(request)
        
        // Extract display name from email (username)
        let displayName = email.components(separatedBy: "@").first ?? "Volunteer"
        
        return AuthSession(
            token: response.access,
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
}

// MARK: - DTOs

struct AuthSession: Equatable, Codable {
    let token: String
    let displayName: String

    init(token: String, displayName: String) {
        self.token = token
        self.displayName = displayName
    }
}

extension LiveLoginAPIService {
    struct LoginRequest: Codable {
        let username: String
        let password: String
    }
    
    struct LoginResponse: Codable {
        let access: String
        let refresh: String
    }
}

// MARK: - Mock Implementation

struct MockLoginAPIService: LoginAPIService {
    func login(email: String, password: String) async throws -> AuthSession {
        try await Task.sleep(nanoseconds: 1_000_000_000)

        guard password.lowercased() == "password" else {
            throw MockAPIError.invalidCredentials
        }

        return AuthSession(
            token: UUID().uuidString,
            displayName: email.components(separatedBy: "@").first ?? "Volunteer"
        )
    }

    func sendPasswordReset(email: String) async throws {
        try await Task.sleep(nanoseconds: 600_000_000)

        if email.isEmpty {
            throw MockAPIError.invalidCredentials
        }
    }
}

// MARK: - Mock Errors

enum MockAPIError: Error, LocalizedError, Equatable {
    case invalidCredentials
    case offline

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "That email and password combo does not look right."
        case .offline:
            "We could not reach the server. Please try again."
        }
    }
}
