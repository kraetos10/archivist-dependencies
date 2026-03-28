#if os(watchOS)
import ArchivistNetworking
import Foundation
import WatchConnectivity

@MainActor
public final class WatchSessionManager: NSObject, WCSessionDelegate {
    public static let shared = WatchSessionManager()
    public var onConfigReceived: ((ServerConfig) -> Void)?
    public var config: WatchAppConfig?

    override public init() {
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
            ["request": "serverConfig"],
            replyHandler: { reply in
                guard let data = reply["serverConfig"] as? Data,
                      let serverConfig = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
                    return
                }
                Task { @MainActor [weak self] in
                    self?.handleReceivedConfig(data: data, serverConfig: serverConfig)
                }
            },
            errorHandler: nil
        )
    }

    // MARK: - WCSessionDelegate

    nonisolated public func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if activationState == .activated {
            Task { @MainActor in
                requestConfigFromiPhone()
            }
        }
    }

    nonisolated public func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let data = applicationContext["serverConfig"] as? Data,
              let serverConfig = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return
        }
        Task { @MainActor in
            handleReceivedConfig(data: data, serverConfig: serverConfig)
        }
    }

    // MARK: - Private

    private func handleConfigReply(_ reply: [String: Any]) {
        guard let data = reply["serverConfig"] as? Data,
              let serverConfig = try? JSONDecoder().decode(ServerConfig.self, from: data) else {
            return
        }
        handleReceivedConfig(data: data, serverConfig: serverConfig)
    }

    private func handleReceivedConfig(
        data: Data,
        serverConfig: ServerConfig
    ) {
        guard let appConfig = config else { return }

        if let defaults = UserDefaults(suiteName: appConfig.appGroupSuite) {
            defaults.set(data, forKey: appConfig.serverConfigKey)
        }

        onConfigReceived?(serverConfig)
    }
}
#endif
