import Foundation

public struct RegistrationDetails: Sendable {
    public var serverAddress: String = ""
    public var port: String = ""
    public var useHTTP: Bool = false

    public init() {}
}

extension RegistrationDetails: Equatable {
    nonisolated public static func == (
        lhs: RegistrationDetails,
        rhs: RegistrationDetails
    ) -> Bool {
        lhs.serverAddress == rhs.serverAddress
            && lhs.port == rhs.port
            && lhs.useHTTP == rhs.useHTTP
    }
}
