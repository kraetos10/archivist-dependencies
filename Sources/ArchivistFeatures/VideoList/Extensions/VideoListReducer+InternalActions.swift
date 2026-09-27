import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoListReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .videosResult(.success(let response)):
            return handleVideosLoaded(response, state: &state)
        case .videosResult(.failure(let error)):
            return handleVideosFailed(error, state: &state)
        case .contextDeleteResult(.success(let videoId)):
            state.videos.remove(id: videoId)
            state.recomputeHomeSections()
            return .none
        case .contextDeleteResult(.failure(let error)):
            return showError(error, state: &state)
        case .searchResult(.success(let videos)):
            return handleSearchResultsLoaded(videos, state: &state)
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .markWatchedResult(.success(let videoId)):
            return refreshVideo(videoId: videoId, config: state.serverConfig)
        case .markWatchedResult(.failure(let error)):
            return showError(error, state: &state)
        case .videoRefreshed(let video):
            state.videos.updateOrAppend(video)
            state.recomputeHomeSections()
            return .none
        case .downloadedVideosLoaded(let videos):
            state.downloadedVideos = IdentifiedArrayOf(uniqueElements: videos)
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
        // Decided by the page that came back, not by a loading flag: only
        // the first page is a full refresh.
        if response.paginate.currentPage == 1 {
            state.videos = IdentifiedArrayOf(uniqueElements: response.data)
            state.searchResults = []
        } else {
            for video in response.data {
                state.videos.updateOrAppend(video)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        state.recomputeHomeSections()
        // downloadedVideoIDs is reactive via @FetchAll

        // Cache video data + thumbnails for Top Shelf, off the reducer.
        let unwatched = Array(state.videos.filter { !$0.isWatched })
        let config = state.serverConfig
        return .run { [topShelf] _ in
            await topShelf.cache(unwatched, config)
        }
    }

    private func handleVideosFailed(
        _ error: Error,
        state: inout State
    ) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return showError(error, state: &state)
    }

    private func handleSearchResultsLoaded(
        _ videos: [VideoResponse],
        state: inout State
    ) -> Effect<Action> {
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
        return .run { [clock, searchService] send in
            try await clock.sleep(for: .milliseconds(400))
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result.map { $0.videoResults ?? [] }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    /// An error never replaces what's already on screen: a late failure
    /// (a page load, a context-menu write) mustn't close an open video.
    private func showError(
        _ error: Error,
        state: inout State
    ) -> Effect<Action> {
        guard state.destination == nil else { return .none }
        state.destination = .alert(AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(error.localizedDescription)
        })
        return .none
    }
}
