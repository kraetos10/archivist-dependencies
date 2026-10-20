#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct DiscoverReducerTests {
    let config = TestFixtures.serverConfig

    private let videoA = YouTubeVideo(videoId: "aaa", title: "A", channelId: "UC1", channelTitle: "One")
    private let videoB = YouTubeVideo(videoId: "bbb", title: "B", channelId: "UC2", channelTitle: "Two")
    private let channel1 = YouTubeChannel(channelId: "UC1", title: "One")

    private func makeStore(
        key: String? = "KEY",
        archived: Set<String> = [],
        submittedQuery: String = "",
        configure: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStore<DiscoverReducer.State, DiscoverReducer.Action> {
        var state = DiscoverReducer.State(serverConfig: config)
        state.apiKey = key
        state.hasLoadedKey = key != nil
        state.submittedQuery = submittedQuery
        state.query = submittedQuery
        let store = TestStore(initialState: state) {
            DiscoverReducer()
        } withDependencies: {
            $0.youTubeAPIKeyStore = .inMemory(key)
            $0.videoService.getVideo = { [archived] _, id in
                guard archived.contains(id) else { throw NetworkingError.errorStatusCode(404, "") }
                return TestFixtures.video1
            }
            $0.channelService.getChannel = { _, _ in throw NetworkingError.errorStatusCode(404, "") }
            $0.playlistService.getPlaylist = { _, _ in throw NetworkingError.errorStatusCode(404, "") }
            // Nothing watched, so no shelves unless a test supplies some.
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in TestFixtures.emptyVideos }
            $0.discoverCache = .inMemory()
            $0.date.now = Date(timeIntervalSince1970: 1_700_000_000)
            configure(&$0)
        }
        // Archive lookups arrive on their own schedule; their effect on
        // state is asserted separately.
        store.exhaustivity = .off
        return store
    }

    // MARK: - Key

    @Test func firstVisitWithoutAKeyPromptsSetupOnce() async {
        let store = makeStore(key: nil)

        await store.send(.view(.viewDidAppear))
        await store.receive(\.keyLoaded) {
            $0.hasLoadedKey = true
            $0.hasPromptedSetup = true
            $0.setup = DiscoverSetupReducer.State()
        }

        await store.send(.setup(.presented(.delegate(.cancelled)))) { $0.setup = nil }
        // Coming back to the tab doesn't nag again.
        await store.send(.view(.viewDidAppear))
        await store.receive(\.keyLoaded)
        #expect(store.state.setup == nil)
        #expect(store.state.needsSetup)
    }

    @Test func aSavedKeyLoadsTrending() async {
        let store = makeStore(key: nil) {
            $0.youTubeSearchService.trending = { key, _, _, _ in
                #expect(key == "KEY")
                return YouTubePage(items: [videoA], nextPageToken: "P2")
            }
        }

        await store.send(.view(.setUpKeyTapped))
        await store.send(.setup(.presented(.delegate(.keySaved("KEY")))))
        await store.receive(\.feedResult)
        #expect(store.state.videos == [videoA])
        #expect(store.state.nextPageToken == "P2")
        #expect(store.state.isShowingTrending)
        #expect(!store.state.needsSetup)
    }

    @Test func aRejectedKeyIsForgottenAndSetupReopens() async {
        let keyStore = YouTubeAPIKeyStore.inMemory("KEY")
        let store = makeStore {
            $0.youTubeAPIKeyStore = keyStore
            $0.youTubeSearchService.searchVideos = { _, _, _, _, _ in throw YouTubeError.invalidKey }
        }

        store.exhaustivity = .on
        await store.send(.binding(.set(\.query, "swift"))) { $0.query = "swift" }
        await store.send(.view(.searchSubmitted)) {
            $0.submittedQuery = "swift"
            $0.isLoading = true
        }
        await store.receive(\.feedResult) {
            $0.isLoading = false
            $0.apiKey = nil
            $0.setup = DiscoverSetupReducer.State(wasKeyRejected: true)
        }
        #expect(keyStore.load() == nil)
    }

    // MARK: - Search

    @Test func submittingASearchReplacesTheListAndPagingAppends() async {
        let store = makeStore {
            $0.youTubeSearchService.searchVideos = { _, query, _, _, pageToken in
                #expect(query == "swift")
                return pageToken == nil
                    ? YouTubePage(items: [videoA], nextPageToken: "P2")
                    : YouTubePage(items: [videoA, videoB], nextPageToken: nil)
            }
        }

        await store.send(.binding(.set(\.query, "  swift "))) 
        await store.send(.view(.searchSubmitted))
        await store.receive(\.feedResult)
        #expect(store.state.submittedQuery == "swift")
        #expect(store.state.videos == [videoA])

        await store.send(.view(.lastItemAppeared))
        await store.receive(\.feedResult)
        // The repeated video isn't added twice.
        #expect(store.state.videos == [videoA, videoB])
        #expect(store.state.nextPageToken == nil)
    }

    @Test func clearingTheFieldReturnsToTrending() async {
        let store = makeStore(submittedQuery: "swift") {
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: [videoB]) }
        }

        await store.send(.binding(.set(\.query, "")))
        await store.receive(\.feedResult)
        #expect(store.state.submittedQuery.isEmpty)
        #expect(store.state.videos == [videoB])
    }

    @Test func channelsNeedAQueryBeforeAnythingLoads() async {
        let store = makeStore()

        await store.send(.binding(.set(\.searchScope, .channels)))
        #expect(store.state.showsSearchPrompt)
        #expect(!store.state.isLoading)
    }

    @Test func runningOutOfQuotaShowsTheBanner() async {
        let store = makeStore {
            $0.youTubeSearchService.searchVideos = { _, _, _, _, _ in throw YouTubeError.quotaExceeded }
        }

        await store.send(.binding(.set(\.query, "swift")))
        await store.send(.view(.searchSubmitted))
        await store.receive(\.feedResult)
        #expect(store.state.isQuotaExceeded)
        #expect(store.state.errorMessage == nil)
    }

    @Test func videosAlreadyOnTheServerAreMarked() async {
        let store = makeStore(archived: ["aaa"]) {
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: [videoA, videoB]) }
        }

        await store.send(.view(.viewDidAppear))
        await store.receive(\.keyLoaded)
        await store.receive(\.feedResult)
        await store.receive(\.statusesLoaded)
        #expect(store.state.itemStatus["aaa"] == .inArchive)
        #expect(store.state.itemStatus["bbb"] == nil)
    }

    // MARK: - Adding

    @Test func addingToTheQueueSendsTheIdAndMarksItQueued() async {
        let sent = LockIsolated<[(items: [AddDownloadItem], autostart: Bool, flat: Bool, force: Bool)]>([])
        let store = makeStore {
            $0.downloadService.addDownloads = { _, items, autostart, flat, force in
                sent.withValue { $0.append((items, autostart, flat, force)) }
            }
        }

        await store.send(.view(.addToQueueTapped(videoA, startNow: false)))
        #expect(store.state.pendingIds == ["aaa"])
        await store.receive(\.addResult)
        await store.receive(\.delegate.didQueueDownload)
        #expect(store.state.itemStatus["aaa"] == .queued)
        #expect(store.state.pendingIds.isEmpty)

        #expect(sent.value.count == 1)
        #expect(sent.value.first?.items.first?.youtubeId == "aaa")
        #expect(sent.value.first?.items.first?.status == "pending")
        #expect(sent.value.first?.autostart == false)

        // Already queued: a second tap does nothing.
        await store.send(.view(.addToQueueTapped(videoA, startNow: true)))
        #expect(sent.value.count == 1)
    }

    @Test func addAndDownloadNowAutostarts() async {
        let autostart = LockIsolated<Bool?>(nil)
        let store = makeStore {
            $0.downloadService.addDownloads = { _, _, start, _, _ in autostart.setValue(start) }
        }

        await store.send(.view(.addToQueueTapped(videoA, startNow: true)))
        await store.receive(\.addResult)
        await store.receive(\.delegate.didQueueDownload)
        #expect(autostart.value == true)
    }

    @Test func aFailedAddRaisesAnAlertAndAllowsRetry() async {
        let store = makeStore {
            $0.downloadService.addDownloads = { _, _, _, _, _ in throw NetworkingError.missingData }
        }

        await store.send(.view(.addToQueueTapped(videoA, startNow: false)))
        await store.receive(\.addResult)
        #expect(store.state.alert != nil)
        #expect(store.state.itemStatus["aaa"] == nil)
        #expect(store.state.pendingIds.isEmpty)
    }

    // MARK: - Subscribing

    @Test func subscribingSendsTheChannelId() async {
        let items = LockIsolated<[ChannelSubscribeItem]>([])
        let store = makeStore {
            $0.channelService.subscribeChannels = { _, sent in items.setValue(sent) }
        }

        await store.send(.view(.subscribeTapped(channel1)))
        await store.receive(\.subscribeResult)
        #expect(store.state.subscribedChannelIds == ["UC1"])
        #expect(items.value.first?.channelId == "UC1")
        #expect(items.value.first?.channelSubscribed == true)
    }

    // MARK: - Channel page

    @Test func openingAChannelLoadsItsUploadsAndDetails() async {
        let detailed = YouTubeChannel(channelId: "UC1", title: "One", channelDescription: "About")
        let store = makeStore {
            $0.youTubeSearchService.channelUploads = { _, id, _ in
                #expect(id == "UC1")
                return YouTubePage(items: [videoA])
            }
            $0.youTubeSearchService.channelDetails = { _, _ in detailed }
        }

        await store.send(.view(.videoChannelTapped(videoA)))
        #expect(store.state.browsedChannel?.channelId == "UC1")
        // The uploads, the header details and the archive lookups all land
        // on their own schedule.
        await store.finish()
        await store.skipReceivedActions()
        #expect(store.state.channelVideos == [videoA])
        #expect(store.state.browsedChannel == detailed)

        // Popping the page clears it.
        await store.send(.binding(.set(\.browsedChannel, nil)))
        #expect(store.state.channelVideos.isEmpty)
    }

    // MARK: - Shelves

    private let watchedByChannel = PaginatedResponse<VideoResponse>(
        data: [TestFixtures.video1, TestFixtures.video2],
        paginate: TestFixtures.paginatedVideos.paginate
    )

    @Test func shelvesAreBuiltFromWhatWasWatchedAndCached() async {
        let saved = LockIsolated<[String]>([])
        let fresh = YouTubeVideo(videoId: "fresh", title: "Fresh", channelId: "UC_channel1", channelTitle: "One")
        let similar = YouTubeVideo(videoId: "similar", title: "Similar", channelId: "UC9", channelTitle: "Nine")
        let store = makeStore(key: nil) {
            $0.videoService.getVideos = { [watchedByChannel] _, _, _, _, _, _, _, _ in watchedByChannel }
            $0.discoverCache = DiscoverCache(
                load: { _ in nil },
                save: { name, _ in saved.withValue { $0.append(name) } }
            )
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: []) }
            $0.youTubeSearchService.channelUploads = { _, channelId, _ in
                #expect(channelId == "UC_channel1")
                return YouTubePage(items: [fresh])
            }
            $0.youTubeSearchService.searchVideos = { _, query, _, filters, _ in
                #expect(query == "Test Video 1")
                #expect(!filters.isActive)
                return YouTubePage(items: [similar])
            }
        }

        await store.send(.view(.setUpKeyTapped))
        await store.send(.setup(.presented(.delegate(.keySaved("KEY")))))
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.shelves.map(\.id) == ["channels", "because-video_1"])
        #expect(store.state.shelves.first?.videos == [fresh])
        #expect(store.state.shelves.last?.videos == [similar])
        #expect(saved.value.count == 1)
    }

    @Test func cachedShelvesAreUsedWithoutTouchingYouTube() async throws {
        let cached = [DiscoverShelf(id: "channels", title: "Cached", videos: [videoA])]
        let data = try JSONEncoder().encode(cached)
        let store = makeStore(key: nil) {
            $0.discoverCache = DiscoverCache(load: { _ in data }, save: { _, _ in })
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: []) }
            // No `channelUploads` or `searchVideos`: either would fail the test.
        }

        await store.send(.view(.setUpKeyTapped))
        await store.send(.setup(.presented(.delegate(.keySaved("KEY")))))
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.shelves == cached)
    }

    @Test func nothingWatchedMeansNoShelvesAndNothingCached() async {
        let saved = LockIsolated(0)
        let store = makeStore(key: nil) {
            $0.discoverCache = DiscoverCache(load: { _ in nil }, save: { _, _ in saved.withValue { $0 += 1 } })
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: []) }
        }

        await store.send(.view(.setUpKeyTapped))
        await store.send(.setup(.presented(.delegate(.keySaved("KEY")))))
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.shelves.isEmpty)
        #expect(saved.value == 0)
    }

    @Test func runningOutOfQuotaWhileBuildingShelvesShowsTheBanner() async {
        let store = makeStore(key: nil) {
            $0.videoService.getVideos = { [watchedByChannel] _, _, _, _, _, _, _, _ in watchedByChannel }
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: []) }
            $0.youTubeSearchService.channelUploads = { _, _, _ in throw YouTubeError.quotaExceeded }
        }

        await store.send(.view(.setUpKeyTapped))
        await store.send(.setup(.presented(.delegate(.keySaved("KEY")))))
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.isQuotaExceeded)
        #expect(store.state.shelves.isEmpty)
    }

    @Test func aNetworkFailureBuildingShelvesLeavesTrendingAlone() async {
        let store = makeStore(key: nil) {
            $0.videoService.getVideos = { _, _, _, _, _, _, _, _ in throw NetworkingError.missingData }
            $0.youTubeSearchService.trending = { _, _, _, _ in YouTubePage(items: [videoB]) }
        }

        await store.send(.view(.setUpKeyTapped))
        await store.send(.setup(.presented(.delegate(.keySaved("KEY")))))
        await store.finish()
        await store.skipReceivedActions()

        #expect(store.state.videos == [videoB])
        #expect(store.state.errorMessage == nil)
        #expect(!store.state.isQuotaExceeded)
    }

    @Test func shelvesOnlySitAboveTheOverallChart() {
        var state = DiscoverReducer.State(serverConfig: config)
        state.shelves = [DiscoverShelf(id: "x", title: "X", videos: [videoA])]
        #expect(state.showsShelves)

        state.trendingCategory = .music
        #expect(!state.showsShelves)

        state.trendingCategory = nil
        state.submittedQuery = "swift"
        #expect(!state.showsShelves)
    }

    // MARK: - Categories and filters

    @Test func choosingACategoryNarrowsTrending() async {
        let seen = LockIsolated<[String?]>([])
        let store = makeStore {
            $0.youTubeSearchService.trending = { _, _, category, _ in
                seen.withValue { $0.append(category) }
                return YouTubePage(items: [videoA])
            }
        }

        await store.send(.view(.categorySelected(.music)))
        await store.receive(\.feedResult)
        #expect(store.state.trendingCategory == .music)
        #expect(seen.value == ["10"])

        // The same chip again is not a new question.
        await store.send(.view(.categorySelected(.music)))
        #expect(seen.value == ["10"])

        await store.send(.view(.categorySelected(nil)))
        await store.receive(\.feedResult)
        #expect(seen.value == ["10", nil])
    }

    @Test func changingAFilterSearchesAgainWithIt() async {
        let filters = LockIsolated<[YouTubeSearchFilters]>([])
        let store = makeStore(submittedQuery: "swift") {
            $0.youTubeSearchService.searchVideos = { _, _, _, applied, _ in
                filters.withValue { $0.append(applied) }
                return YouTubePage(items: [videoA])
            }
        }

        await store.send(.binding(.set(\.filters.duration, .long)))
        await store.receive(\.feedResult)

        #expect(filters.value == [YouTubeSearchFilters(duration: .long)])
        #expect(store.state.filters.isActive)
    }

    // MARK: - Playlists

    @Test func playlistsAreSearchedAndSubscribedTo() async {
        let playlist = YouTubePlaylist(playlistId: "PL1", title: "Mix", channelTitle: "Chan", itemCount: 3)
        let subscribed = LockIsolated<[PlaylistSubscribeItem]>([])
        let store = makeStore {
            $0.youTubeSearchService.searchPlaylists = { _, query, _ in
                #expect(query == "swift")
                return YouTubePage(items: [playlist])
            }
            $0.playlistService.subscribePlaylists = { _, items in subscribed.setValue(items) }
        }

        // Nothing to show until there's a query.
        await store.send(.binding(.set(\.searchScope, .playlists)))
        #expect(store.state.showsSearchPrompt)

        await store.send(.binding(.set(\.query, "swift")))
        await store.send(.view(.searchSubmitted))
        await store.receive(\.feedResult)
        #expect(store.state.playlists == [playlist])

        await store.send(.view(.subscribePlaylistTapped(playlist)))
        await store.receive(\.subscribePlaylistResult)
        #expect(store.state.subscribedPlaylistIds == ["PL1"])
        #expect(subscribed.value.first?.playlistId == "PL1")
        #expect(subscribed.value.first?.playlistSubscribed == true)

        // Already subscribed: a second tap does nothing.
        await store.send(.view(.subscribePlaylistTapped(playlist)))
        #expect(subscribed.value.count == 1)
    }

    @Test func playlistsAlreadyOnTheServerAreMarkedSubscribed() async {
        let playlist = YouTubePlaylist(playlistId: "PL1", title: "Mix")
        let store = makeStore(submittedQuery: "swift") {
            $0.youTubeSearchService.searchPlaylists = { _, _, _ in YouTubePage(items: [playlist]) }
            $0.playlistService.getPlaylist = { _, _ in
                PlaylistResponse(
                    playlistId: "PL1",
                    playlistName: "Mix",
                    playlistType: TestFixtures.playlist1.playlistType,
                    playlistChannelId: nil,
                    playlistChannel: nil,
                    playlistDescription: nil,
                    playlistThumbnail: nil,
                    playlistSubscribed: true,
                    playlistActive: true,
                    playlistSortOrder: nil,
                    playlistLastRefresh: nil,
                    playlistEntries: nil
                )
            }
        }

        await store.send(.binding(.set(\.searchScope, .playlists)))
        await store.receive(\.feedResult)
        await store.receive(\.statusesLoaded)

        #expect(store.state.subscribedPlaylistIds == ["PL1"])
    }
}
#endif
