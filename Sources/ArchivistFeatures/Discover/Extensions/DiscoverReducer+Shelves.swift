#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DiscoverReducer {
    /// How long a set of shelves is reused before being built again. A
    /// search costs 100 units of the key's 10,000 a day, so rebuilding on
    /// every visit would spend the allowance in a day.
    static let shelfLifetime: Duration = .seconds(12 * 60 * 60)

    /// The server and region decide the shelves; the bucket is half a day.
    func shelvesCacheName(config: ServerConfig) -> String {
        let region = Locale.current.region?.identifier ?? ""
        let bucket = Int(now.timeIntervalSince1970 / 43_200)
        return "shelves-v2|\(config.baseURL)|\(region)|\(bucket)"
    }

    func loadShelves(state: inout State) -> Effect<Action> {
        guard let key = state.apiKey, state.shelves.isEmpty, !state.isLoadingShelves else { return .none }
        state.isLoadingShelves = true
        let config = state.serverConfig
        let cacheName = shelvesCacheName(config: config)
        return .run { [youTubeSearchService, videoService, discoverCache] send in
            if let data = discoverCache.load(name: cacheName),
               let cached = try? JSONDecoder().decode([DiscoverShelf].self, from: data) {
                await send(.shelvesLoaded(.success(cached)))
                return
            }
            let result = await Result { () -> [DiscoverShelf] in
                let watched = try await videoService.getVideos(
                    config: config,
                    page: 1,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: "watched",
                    channel: nil,
                    playlist: nil
                )
                let taste = DiscoverTaste(watched: watched.data)
                guard !taste.isEmpty else { return [] }
                let shelves = try await Self.buildShelves(
                    taste: taste,
                    key: key,
                    service: youTubeSearchService
                )
                if !shelves.isEmpty, let data = try? JSONEncoder().encode(shelves) {
                    discoverCache.save(name: cacheName, data: data)
                }
                return shelves
            }
            await send(.shelvesLoaded(result))
        }
        .cancellable(id: CancelID.shelves, cancelInFlight: true)
    }

    /// Latest uploads of the most-watched channels, then a "because you
    /// watched" search for each seed. One failing lookup costs its own
    /// shelf, not the rest; running out of quota stops everything, since
    /// every later call would fail the same way.
    static func buildShelves(
        taste: DiscoverTaste,
        key: String,
        service: YouTubeSearchService
    ) async throws -> [DiscoverShelf] {
        var shelves: [DiscoverShelf] = []

        let uploads = await withTaskGroup(of: Result<[YouTubeVideo], Error>.self) { group in
            for channel in taste.channels {
                group.addTask {
                    await Result {
                        try await service.channelUploads(key: key, channelId: channel.id, pageToken: nil).items
                    }
                }
            }
            var all: [Result<[YouTubeVideo], Error>] = []
            for await result in group { all.append(result) }
            return all
        }
        try Self.rethrowQuota(uploads)
        if let shelf = DiscoverShelves.channelShelf(
            uploads: uploads.compactMap { try? $0.get() },
            excluding: taste.watchedIds
        ) {
            shelves.append(shelf)
        }

        for seed in taste.seeds {
            let query = DiscoverShelves.searchQuery(fromTitle: seed.title)
            guard !query.isEmpty else { continue }
            let result = await Result {
                try await service.searchVideos(
                    key: key,
                    query: query,
                    order: .relevance,
                    filters: YouTubeSearchFilters(),
                    pageToken: nil
                ).items
            }
            try Self.rethrowQuota([result])
            if let videos = try? result.get(),
               let shelf = DiscoverShelves.becauseShelf(
                   seed: seed,
                   results: videos,
                   excluding: taste.watchedIds,
                   choices: taste.choices
               ) {
                shelves.append(shelf)
            }
        }
        return shelves
    }

    private static func rethrowQuota<T>(_ results: [Result<T, Error>]) throws {
        for case .failure(let error) in results {
            if let error = error as? YouTubeError, error == .quotaExceeded || error == .invalidKey {
                throw error
            }
        }
    }

    /// Switches a "because you watched" row to another video. The row keeps
    /// its place and shows placeholders until the new videos arrive.
    func handleBecauseVideoSelected(
        shelfId: String,
        choice: DiscoverShelf.Choice,
        state: inout State
    ) -> Effect<Action> {
        guard let key = state.apiKey,
              let shelf = state.shelves.first(where: { $0.id == shelfId }),
              shelf.seedId != choice.videoId,
              !state.shelves.contains(where: { $0.seedId == choice.videoId }) else { return .none }
        state.loadingShelfIds.insert(shelfId)
        let config = state.serverConfig
        let region = Locale.current.region?.identifier ?? ""
        let bucket = Int(now.timeIntervalSince1970 / 43_200)
        let cacheName = "because-v1|\(config.baseURL)|\(region)|\(bucket)|\(choice.videoId)"
        let excluded = Set(shelf.choices.map(\.videoId))
        let seed = DiscoverTaste.Seed(videoId: choice.videoId, title: choice.title)
        return .run { [youTubeSearchService, discoverCache] send in
            if let data = discoverCache.load(name: cacheName),
               let cached = try? JSONDecoder().decode(DiscoverShelf.self, from: data) {
                await send(.becauseShelfLoaded(shelfId: shelfId, .success(cached)))
                return
            }
            let result = await Result { () -> DiscoverShelf? in
                let query = DiscoverShelves.searchQuery(fromTitle: seed.title)
                guard !query.isEmpty else { return nil }
                let videos = try await youTubeSearchService.searchVideos(
                    key: key,
                    query: query,
                    order: .relevance,
                    filters: YouTubeSearchFilters(),
                    pageToken: nil
                ).items
                let shelf = DiscoverShelves.becauseShelf(
                    seed: seed,
                    results: videos,
                    excluding: excluded
                )
                if let shelf, let data = try? JSONEncoder().encode(shelf) {
                    discoverCache.save(name: cacheName, data: data)
                }
                return shelf
            }
            await send(.becauseShelfLoaded(shelfId: shelfId, result))
        }
        .cancellable(id: CancelID.because(shelfId), cancelInFlight: true)
    }

    func handleBecauseShelfLoaded(
        shelfId: String,
        result: Result<DiscoverShelf?, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.loadingShelfIds.remove(shelfId)
        switch result {
        case .success(let replacement):
            // Nothing similar came back: the row keeps what it had.
            guard let replacement,
                  let index = state.shelves.firstIndex(where: { $0.id == shelfId }) else { return .none }
            state.shelves[index].seedId = replacement.seedId
            state.shelves[index].title = replacement.title
            state.shelves[index].videos = replacement.videos
            let shelves = state.shelves
            let cacheName = shelvesCacheName(config: state.serverConfig)
            return .merge(
                statusEffect(
                    videoIds: replacement.videos.map(\.videoId),
                    channelIds: [],
                    state: state
                ),
                // So the choice is still there next time, until the shelves expire.
                .run { [discoverCache] _ in
                    if let data = try? JSONEncoder().encode(shelves) {
                        discoverCache.save(name: cacheName, data: data)
                    }
                }
            )
        case .failure(let error):
            if let error = error as? YouTubeError, error == .quotaExceeded || error == .invalidKey {
                return handleFailure(error, state: &state)
            }
            return .none
        }
    }

    func handleShelvesLoaded(
        _ result: Result<[DiscoverShelf], Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isLoadingShelves = false
        switch result {
        case .success(let shelves):
            state.shelves = shelves
            return statusEffect(
                videoIds: shelves.flatMap { $0.videos.map(\.videoId) },
                channelIds: [],
                state: state
            )
        case .failure(let error):
            // Shelves are a bonus: a network failure leaves Trending to
            // speak for itself. Quota and a dead key matter everywhere.
            if let error = error as? YouTubeError, error == .quotaExceeded || error == .invalidKey {
                return handleFailure(error, state: &state)
            }
            return .none
        }
    }
}
#endif
