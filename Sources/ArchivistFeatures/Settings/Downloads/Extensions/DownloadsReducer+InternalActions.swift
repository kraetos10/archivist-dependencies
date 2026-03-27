import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
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
            state.downloads.remove(id: videoId)
            return .none
        case .deleteResult(.failure):
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleDownloadsLoaded(_ response: PaginatedResponse<DownloadResponse>, state: inout State) -> Effect<Action> {
        if state.isLoading {
            state.downloads = IdentifiedArrayOf(uniqueElements: response.data)
        } else {
            for download in response.data {
                state.downloads.updateOrAppend(download)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        state.downloads.sort { lhs, rhs in
            (lhs.published ?? "") > (rhs.published ?? "")
        }
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

    private func handleDownloadsFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }
}
