import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension VideoListReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videosLoaded(let response):
            return handleVideosLoaded(response, state: &state)
        case .videosFailed(let error):
            return handleVideosFailed(error, state: &state)
        case .contextDeleteCompleted(let videoId):
            state.videos.remove(id: videoId)
            return .none
        case .contextDeleteFailed(let error):
            return handleContextDeleteFailed(error, state: &state)
        case .searchResultsLoaded(let videos):
            return handleSearchResultsLoaded(videos, state: &state)
        case .searchFailed:
            state.isSearching = false
            return .none
        case .markWatchedCompleted(let videoId):
            let config = state.serverConfig
            return .run { [videoService] send in
                if let video = try? await videoService.getVideo(config: config, id: videoId) {
                    await send(.videoRefreshed(video))
                }
            }

        case .markWatchedFailed:
            return .none
        case .videoRefreshed(let video):
            state.videos.updateOrAppend(video)
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
            state.videos = IdentifiedArrayOf(uniqueElements: response.data)
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
            TextState(String(localized: "Error"))
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
            do {
                let response = try await searchService.search(config: config, query: query)
                await send(.searchResultsLoaded(response.videoResults ?? []))
            } catch {
                await send(.searchFailed)
            }
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handleContextDeleteFailed(_ error: Error, state: inout State) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String(localized: "Error"))
        } message: {
            TextState(error.localizedDescription)
        }
        return .none
    }
}
