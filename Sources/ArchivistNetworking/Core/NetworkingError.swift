import Foundation

public nonisolated enum NetworkingError: Error, Equatable, Sendable {
    case invalidURL
    case missingData
    case errorStatusCode(Int, String)
    /// The response arrived but didn't match the expected model. Carries the
    /// decoder's description so the mismatch is visible when it's reported.
    case decodingFailed(String)

    /// Maps a non-2xx response to an error, keeping the body for diagnostics.
    public init(
        statusCode: Int,
        body: Data
    ) {
        self = .errorStatusCode(statusCode, String(bytes: body, encoding: .utf8) ?? "")
    }

    public var description: String {
        switch self {
        case let .errorStatusCode(statusCode, description):
            "\(statusCode) - \(description)"
        case .invalidURL:
            "Invalid URL"
        case .missingData:
            "Missing data"
        case let .decodingFailed(description):
            "Decoding failed - \(description)"
        }
    }

    /// User-facing message suitable for display in alerts.
    ///
    /// English only: ArchivistNetworking has no string catalog of its own and
    /// can't reach the ArchivistComponents tables, so screens that need a
    /// localised message map the error themselves.
    public var userMessage: String {
        switch self {
        case .errorStatusCode(401, _), .errorStatusCode(403, _):
            "Invalid or expired token"
        case .errorStatusCode(let code, _):
            "Server error (\(code))"
        case .invalidURL:
            "Invalid server URL"
        case .missingData:
            "No response from server"
        case .decodingFailed:
            "Unexpected response from server"
        }
    }

    /// Whether this error indicates an authentication/authorization failure.
    public var isAuthError: Bool {
        switch self {
        case .errorStatusCode(401, _), .errorStatusCode(403, _):
            true
        default:
            false
        }
    }

    /// The server rejected the API token itself (as opposed to, say, a
    /// permission error on one endpoint), so the session should end.
    public var isInvalidToken: Bool {
        guard case let .errorStatusCode(code, body) = self,
              code == 401 || code == 403 else { return false }
        return body.localizedCaseInsensitiveContains("invalid token")
    }
}

extension Error {
    /// User-facing message for display in alerts, handling both NetworkingError and generic errors.
    public var userMessage: String {
        if let networkError = self as? NetworkingError {
            return networkError.userMessage
        }
        return "A network error occurred"
    }
}
