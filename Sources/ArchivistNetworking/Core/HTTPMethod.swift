import Foundation

public nonisolated enum HTTPMethod: String {
    case get = "GET"
    case put = "PUT"
    case post = "POST"
    case patch = "PATCH"
    case delete = "DELETE"
}

public nonisolated final class HTTPHeader {
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
