import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct StatsReducerTests {
    let config = TestFixtures.serverConfig

    private let channelStats = ChannelStatsResponse(
        docCount: 3,
        activeTrue: 3,
        activeFalse: 0,
        subscribedTrue: 2,
        subscribedFalse: 1
    )

    private func history(_ count: Int) -> [DownloadHistResponse] {
        (0..<count).map { DownloadHistResponse(date: "2025-01-\($0 + 1)", count: $0) }
    }

    /// Every section loads at once. The loading flag holds until the last
    /// one has answered, failure or not. The requests run concurrently, so
    /// each is held on its own gate and released in turn.
    @Test func loadingSettlesOnceEverySectionHasAnswered() async {
        let failure = URLError(.timedOut)
        let history = history(2)
        let gates = (0..<7).map { _ in TestGate() }
        let store = TestStore(initialState: StatsReducer.State(serverConfig: config)) {
            StatsReducer()
        } withDependencies: {
            $0.statsService.getVideoStats = { _ in
                await gates[0].wait()
                throw failure
            }
            $0.statsService.getChannelStats = { [channelStats] _ in
                await gates[1].wait()
                return channelStats
            }
            $0.statsService.getPlaylistStats = { _ in
                await gates[2].wait()
                throw failure
            }
            $0.statsService.getDownloadStats = { _ in
                await gates[3].wait()
                throw failure
            }
            $0.statsService.getWatchStats = { _ in
                await gates[4].wait()
                throw failure
            }
            $0.statsService.getBiggestChannels = { _ in
                await gates[5].wait()
                return []
            }
            $0.statsService.getDownloadHistory = { _ in
                await gates[6].wait()
                return history
            }
        }

        await store.send(.view(.viewDidAppear)) {
            $0.isLoading = true
        }
        gates[0].open()
        await store.receive(\.videoStatsResult.failure) {
            $0.loadedSections = [.video]
            $0.hasLoaded = true
        }
        // A failed overview drops its placeholder rather than spinning on.
        #expect(store.state.showsOverviewPlaceholder == false)
        #expect(store.state.showsApplicationPlaceholder)
        gates[1].open()
        await store.receive(\.channelStatsResult.success) {
            $0.channelStats = channelStats
            $0.loadedSections.insert(.channel)
        }
        #expect(store.state.hasApplicationStats)
        gates[2].open()
        await store.receive(\.playlistStatsResult.failure) {
            $0.loadedSections.insert(.playlist)
        }
        gates[3].open()
        await store.receive(\.downloadStatsResult.failure) {
            $0.loadedSections.insert(.download)
        }
        gates[4].open()
        await store.receive(\.watchStatsResult.failure) {
            $0.loadedSections.insert(.watch)
        }
        gates[5].open()
        await store.receive(\.biggestChannelsResult.success) {
            $0.loadedSections.insert(.biggestChannels)
        }
        gates[6].open()
        await store.receive(\.downloadHistoryResult.success) {
            $0.downloadHistory = history
            $0.loadedSections.insert(.downloadHistory)
            $0.isLoading = false
        }
    }

    @Test func appearingAgainDoesNotReload() async {
        var state = StatsReducer.State(serverConfig: config)
        state.hasLoaded = true
        let store = TestStore(initialState: state) {
            StatsReducer()
        }

        await store.send(.view(.viewDidAppear))
    }

    @Test func downloadHistoryCollapsesToAWeekUntilExpanded() async {
        var state = StatsReducer.State(serverConfig: config)
        state.downloadHistory = history(10)
        let store = TestStore(initialState: state) {
            StatsReducer()
        }
        #expect(store.state.canExpandDownloadHistory)
        #expect(store.state.visibleDownloadHistory.count == StatsReducer.State.collapsedHistoryCount)
        #expect(
            store.state.downloadHistoryToggleTitle
                == String.localised("generic.showAll \(10)", table: .generic)
        )

        await store.send(.view(.downloadHistoryToggleTapped)) {
            $0.isDownloadHistoryExpanded = true
        }
        #expect(store.state.visibleDownloadHistory.count == 10)
        #expect(
            store.state.downloadHistoryToggleTitle
                == String.localised("generic.showLess", table: .generic)
        )
    }
}
