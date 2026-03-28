import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadsReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .downloadsResult(.success(let response)):
            return handleDownloadsLoaded(response, state: &state)
        case .downloadsResult(.failure):
            return handleDownloadsFailed(state: &state)
        case .searchResult(.success(let response)):
            state.searchResults = IdentifiedArrayOf(uniqueElements: response.data)
            state.isSearching = false
            return .none
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .deleteResult(.success(let videoId)):
            anchorScrollBeforeRemoval(of: videoId, state: &state)
            state.downloads.remove(id: videoId)
            return .none
        case .deleteResult(.failure):
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleDownloadsLoaded(
        _ response: PaginatedResponse<DownloadResponse>,
        state: inout State
    ) -> Effect<Action> {
        let discoveredLastPage = response.paginate.lastPage

        switch state.sortOrder {
        case .newestFirst:
            // Discovery request: fetch page 1 to learn lastPage, then load from the end
            if state.isLoading && discoveredLastPage > 1 && response.paginate.currentPage == 1 {
                state.lastPage = discoveredLastPage
                return fetchDownloads(config: state.serverConfig, page: discoveredLastPage)
            }

            let reversed = response.data.reversed()
            if state.isLoading {
                state.downloads = IdentifiedArrayOf(uniqueElements: reversed)
            } else {
                for download in reversed {
                    state.downloads.updateOrAppend(download)
                }
            }

        case .oldestFirst:
            if state.isLoading {
                state.downloads = IdentifiedArrayOf(uniqueElements: response.data)
            } else {
                for download in response.data {
                    state.downloads.updateOrAppend(download)
                }
            }
        }

        state.currentPage = response.paginate.currentPage
        state.lastPage = discoveredLastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
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
        let downloadService = self.downloadService
        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            let result = await Result {
                try await downloadService.getDownloads(
                    config: config,
                    page: 1,
                    filter: "pending",
                    channel: nil,
                    query: query,
                    vidType: nil
                )
            }
            await send(.searchResult(result))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    func anchorScrollBeforeRemoval(
        of videoId: String,
        state: inout State
    ) {
        guard let index = state.downloads.index(id: videoId) else { return }
        let nextIndex = state.downloads.index(after: index)
        if nextIndex < state.downloads.endIndex {
            state.scrollPositionID = state.downloads[nextIndex].id
        } else if index > state.downloads.startIndex {
            let prevIndex = state.downloads.index(before: index)
            state.scrollPositionID = state.downloads[prevIndex].id
        }
    }

    private func handleDownloadsFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }
}
