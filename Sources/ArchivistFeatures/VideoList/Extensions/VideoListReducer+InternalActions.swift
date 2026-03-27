import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoListReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videosResult(.success(let response)):
            return handleVideosLoaded(response, state: &state)
        case .videosResult(.failure(let error)):
            return handleVideosFailed(error, state: &state)
        case .contextDeleteResult(.success(let videoId)):
            state.videos.remove(id: videoId)
            return .none
        case .contextDeleteResult(.failure(let error)):
            return handleContextDeleteFailed(error, state: &state)
        case .searchResult(.success(let videos)):
            return handleSearchResultsLoaded(videos, state: &state)
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .markWatchedResult(.success(let videoId)):
            let config = state.serverConfig
            return .run { [videoService] send in
                if let video = try? await videoService.getVideo(config: config, id: videoId) {
                    await send(.videoRefreshed(video))
                }
            }

        case .markWatchedResult(.failure):
            return .none
        case .videoRefreshed(let video):
            state.videos.updateOrAppend(video)
            return .none
        case .pipRestoreVideo(let video):
            let detailState = VideoDetailReducer.State(
                serverConfig: state.serverConfig,
                video: video,
                nextVideos: [],
                isPlaying: true
            )
            #if os(tvOS)
            state.path.append(.videoDetail(detailState))
            #else
            state.videoDetail = detailState
            #endif
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleVideosLoaded(
        _ response: PaginatedResponse<VideoResponse>,
        state: inout State
    ) -> Effect<Action> {
        if state.isLoading {
            // Full refresh — replace everything
            state.videos = IdentifiedArrayOf(uniqueElements: response.data)
            state.searchResults = []
            state.downloadedVideoIDs = []
        } else {
            // Pagination — append
            for video in response.data {
                state.videos.updateOrAppend(video)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        state.videos.sort { lhs, rhs in
            guard let lhsDate = lhs.publishedDate, let rhsDate = rhs.publishedDate else {
                return lhs.publishedDate != nil
            }
            return lhsDate > rhsDate
        }

        // Pre-cache thumbnails for Top Shelf
        let unwatched = state.videos.filter { !$0.isWatched }
        let config = state.serverConfig
        TopShelfCache.cacheVideoThumbnails(
            videos: unwatched.map { (id: $0.videoId, thumbPath: $0.vidThumbUrl) },
            serverConfig: config
        )

        return .none
    }

    private func handleVideosFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        state.alert = AlertState {
            TextState(String.localised("generic.error"))
        } message: {
            TextState(error.localizedDescription)
        }
        return .none
    }

    private func handleSearchResultsLoaded(_ videos: [VideoResponse], state: inout State) -> Effect<Action> {
        state.searchResults = IdentifiedArrayOf(uniqueElements: videos)
        state.isSearching = false
        return .none
    }

    public func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.searchResults = []
            state.isSearching = false
            return .cancel(id: CancelID.search)
        }
        state.isSearching = true
        let config = state.serverConfig
        let clock = self.clock
        let searchService = self.searchService
        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result.map { $0.videoResults ?? [] }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handleContextDeleteFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String.localised("generic.error"))
        } message: {
            TextState(error.localizedDescription)
        }
        return .none
    }
}
