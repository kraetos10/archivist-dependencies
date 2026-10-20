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

    func loadShelves(state: inout State) -> Effect<Action> {
        guard let key = state.apiKey, state.shelves.isEmpty, !state.isLoadingShelves else { return .none }
        state.isLoadingShelves = true
        let config = state.serverConfig
        let region = Locale.current.region?.identifier ?? ""
        let bucket = Int(now.timeIntervalSince1970 / 43_200)
        // The server and region decide the shelves; the bucket is half a day.
        let cacheName = "shelves-v1|\(config.baseURL)|\(region)|\(bucket)"
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
                   excluding: taste.watchedIds
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
