import Foundation

/// What the phone tells the paired watch about the server connection, and
/// the WatchConnectivity dictionary it travels in. Shared by both sides so
/// the keys can't drift apart.
///
/// Sent as the application context (latest state wins, delivered even if
/// the watch app isn't running) and as the reply to the watch asking.
public enum WatchSyncPayload: Equatable, Sendable {
    /// The phone is connected to this server.
    case serverConfig(ServerConfig)
    /// The phone logged out: the watch drops its copy and shows setup.
    case loggedOut

    /// Key for the encoded `ServerConfig`. Matches `ServerConfigStore.defaultKey`,
    /// which older watch builds read.
    public static let serverConfigKey = ServerConfigStore.defaultKey
    /// Key present only in the logged-out message.
    public static let loggedOutKey = "loggedOut"
    /// Key the watch sends in a message to ask for the current payload.
    public static let requestKey = "request"

    /// The request message the watch sends to ask for the current payload.
    public static var requestMessage: [String: Any] {
        [requestKey: serverConfigKey]
    }

    /// The WatchConnectivity dictionary for this payload, or `nil` when the
    /// config can't be encoded.
    public var dictionary: [String: Any]? {
        switch self {
        case .serverConfig(let config):
            guard let data = try? JSONEncoder().encode(config) else { return nil }
            return [Self.serverConfigKey: data]
        case .loggedOut:
            return [Self.loggedOutKey: true]
        }
    }

    /// Reads a payload back out of a WatchConnectivity dictionary. `nil`
    /// for anything else, including an empty reply.
    public init?(dictionary: [String: Any]) {
        if dictionary[Self.loggedOutKey] as? Bool == true {
            self = .loggedOut
            return
        }
        guard let data = dictionary[Self.serverConfigKey] as? Data,
              let config = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return nil
        }
        self = .serverConfig(config)
    }
}
