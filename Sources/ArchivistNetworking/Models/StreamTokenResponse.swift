import Foundation

public struct StreamTokenResponse: Decodable, Sendable {
    public let sig: String
    public let expires: Int

    public init(sig: String, expires: Int) {
        self.sig = sig
        self.expires = expires
    }
}
