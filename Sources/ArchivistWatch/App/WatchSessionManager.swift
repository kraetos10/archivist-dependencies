#if os(watchOS)
import ArchivistNetworking
import Foundation
import WatchConnectivity

/// Receives the server configuration from the paired iPhone and stores it in
/// the App Group, where `WatchAppState` reads it. A logout on the phone
/// clears it, so the watch falls back to its setup screen.
@MainActor
public final class WatchSessionManager: NSObject, WCSessionDelegate {
    /// The configuration changed: a new one from the phone, or `nil` once
    /// the phone has logged out.
    public var onConfigChanged: ((ServerConfig?) -> Void)?
    private let config: WatchAppConfig

    public init(config: WatchAppConfig) {
        self.config = config
        super.init()
    }

    public func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    public func requestConfigFromiPhone() {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(
            WatchSyncPayload.requestMessage,
            replyHandler: { [weak self] reply in
                guard let payload = WatchSyncPayload(dictionary: reply) else { return }
                Task { @MainActor in
                    self?.handle(payload)
                }
            },
            errorHandler: nil
        )
    }

    // MARK: - WCSessionDelegate

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor in
            requestConfigFromiPhone()
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let payload = WatchSyncPayload(dictionary: applicationContext) else { return }
        Task { @MainActor in
            handle(payload)
        }
    }

    // MARK: - Payloads

    /// Stores (or, on logout, removes) the configuration in the App Group
    /// and reports the change.
    func handle(_ payload: WatchSyncPayload) {
        let defaults = UserDefaults(suiteName: config.appGroupSuite)
        switch payload {
        case .serverConfig(let serverConfig):
            guard let data = try? JSONEncoder().encode(serverConfig) else { return }
            defaults?.set(data, forKey: config.serverConfigKey)
            onConfigChanged?(serverConfig)
        case .loggedOut:
            defaults?.removeObject(forKey: config.serverConfigKey)
            onConfigChanged?(nil)
        }
    }
}
#endif
