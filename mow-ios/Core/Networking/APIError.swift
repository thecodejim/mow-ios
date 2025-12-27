import Foundation

// MARK: - API Errors

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
