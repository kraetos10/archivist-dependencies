import Foundation

public nonisolated enum NetworkingError: Error, Equatable {
    case invalidURL
    case missingData
    case errorStatusCode(Int, String)

    public var description: String {
        switch self {
        case let .errorStatusCode(statusCode, description):
            "\(statusCode) - \(description)"
        case .invalidURL:
            "Invalid URL"
        case .missingData:
            "Missing data"
        }
    }

    /// User-facing message suitable for display in alerts.
    @MainActor public var userMessage: String {
        switch self {
        case .errorStatusCode(403, _):
            "Invalid or expired token"
        case .errorStatusCode(let code, _):
            "Server error (\(code))"
        case .invalidURL:
            "Invalid server URL"
        case .missingData:
            "No response from server"
        }
    }

    /// Whether this error indicates an authentication/authorization failure.
    public var isAuthError: Bool {
        if case .errorStatusCode(403, _) = self { return true }
        return false
    }
}

extension Error {
    /// User-facing message for display in alerts, handling both NetworkingError and generic errors.
    @MainActor public var userMessage: String {
        if let networkError = self as? NetworkingError {
            return networkError.userMessage
        }
        return "A network error occurred"
    }
}

extension Notification.Name {
    public static let authTokenExpired = Notification.Name("authTokenExpired")
}
