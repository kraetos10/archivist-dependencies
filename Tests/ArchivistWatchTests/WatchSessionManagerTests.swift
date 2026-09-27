#if os(watchOS)
@testable import ArchivistNetworking
@testable import ArchivistWatch
import Foundation
import Testing

/// The phone's messages as the watch applies them. `handle(_:)` is the
/// whole of it; the WatchConnectivity delegate only decodes and forwards.
@MainActor
@Suite(.timeLimit(.minutes(1)))
struct WatchSessionManagerTests {
    private let config = WatchAppConfig(
        appGroupSuite: "tests.\(UUID().uuidString)",
        backgroundSessionIdentifier: "tests"
    )

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: config.appGroupSuite)
    }

    @Test func aConfigFromThePhoneIsStoredAndApplied() throws {
        let appState = WatchAppState(config: config, playback: WatchFixtures.playback())
        let manager = WatchSessionManager(config: config)
        manager.onConfigChanged = { appState.apply($0) }

        manager.handle(.serverConfig(WatchFixtures.config))

        #expect(appState.tabs?.config == WatchFixtures.config)
        let stored = try #require(defaults?.data(forKey: config.serverConfigKey))
        #expect(try JSONDecoder().decode(ServerConfig.self, from: stored) == WatchFixtures.config)
    }

    @Test func logoutOnThePhoneClearsTheStoredConfigAndShowsSetup() throws {
        let data = try JSONEncoder().encode(WatchFixtures.config)
        defaults?.set(data, forKey: config.serverConfigKey)
        let appState = WatchAppState(config: config, playback: WatchFixtures.playback())
        appState.loadServerConfig()
        #expect(appState.tabs != nil)
        let manager = WatchSessionManager(config: config)
        manager.onConfigChanged = { appState.apply($0) }

        manager.handle(.loggedOut)

        #expect(appState.tabs == nil)
        #expect(defaults?.data(forKey: config.serverConfigKey) == nil)
        // A relaunch reads nothing back, so setup stays up.
        let relaunched = WatchAppState(config: config, playback: WatchFixtures.playback())
        relaunched.loadServerConfig()
        #expect(relaunched.tabs == nil)
    }
}
#endif
