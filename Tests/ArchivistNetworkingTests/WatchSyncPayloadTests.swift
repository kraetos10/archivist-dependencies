import ArchivistNetworking
import Foundation
import Testing

@Suite(.timeLimit(.minutes(1)))
struct WatchSyncPayloadTests {
    let config = ServerConfig(baseURL: "tube.example.com", apiToken: "token")

    @Test func aConfigRoundTripsThroughTheDictionary() throws {
        let dictionary = try #require(WatchSyncPayload.serverConfig(config).dictionary)

        #expect(WatchSyncPayload(dictionary: dictionary) == .serverConfig(config))
        // Older watch builds read the config from this key.
        #expect(dictionary[ServerConfigStore.defaultKey] is Data)
    }

    @Test func logoutRoundTripsThroughTheDictionary() throws {
        let dictionary = try #require(WatchSyncPayload.loggedOut.dictionary)

        #expect(WatchSyncPayload(dictionary: dictionary) == .loggedOut)
    }

    @Test func anEmptyReplyIsNoPayload() {
        #expect(WatchSyncPayload(dictionary: [:]) == nil)
        #expect(WatchSyncPayload(dictionary: [WatchSyncPayload.serverConfigKey: Data("junk".utf8)]) == nil)
    }
}
