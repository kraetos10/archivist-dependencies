import Foundation

public nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

public nonisolated struct HTTPHeader: Sendable, Equatable {
    public let field: String
    public let value: String

    public init(
        field: String,
        value: String
    ) {
        self.field = field
        self.value = value
    }
}
