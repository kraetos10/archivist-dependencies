import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadsReducer {
    /// The detail screen queued or deleted its video (and is closing
    /// itself): drop the row, keeping the scroll position on a neighbour.
    func handleDetailFinished(
        _ videoId: String,
        state: inout State
    ) -> Effect<Action> {
        removeDownload(videoId, state: &state)
        return .none
    }

    /// tvOS "Download Now": remove the row optimistically, bump it on the
    /// server, then reconcile.
    func handleConfirmDownload(
        _ videoId: String,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        removeDownload(videoId, state: &state)
        return .run { [downloadService] send in
            let result = await Result {
                try await downloadService.updateDownload(config: config, id: videoId, status: "priority")
            }
            await send(.bumpResult(result))
        }
    }

    /// Reconcile with the server either way: optimistic removal alone
    /// empties the visible queue when the user bulk-bumps items, and a
    /// failed bump needs its row back.
    func handleBumpResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        if case .failure(let error) = result {
            state.alert = .requestFailed(error)
        }
        return handleRefresh(state: &state)
    }

    func handleDownloadsResult(
        _ result: Result<PaginatedResponse<DownloadResponse>, Error>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success(let response):
            return handleDownloadsLoaded(response, state: &state)
        case .failure(let error):
            state.isLoading = false
            state.isLoadingMore = false
            state.hasLoaded = true
            state.alert = .requestFailed(error)
            return .none
        }
    }

    func handleSearchResult(
        _ result: Result<PaginatedResponse<DownloadResponse>, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isSearching = false
        switch result {
        case .success(let response):
            // The server can repeat an item across a page boundary;
            // `uniqueElements:` would trap on it.
            var results: IdentifiedArrayOf<DownloadResponse> = []
            for download in response.data {
                results.updateOrAppend(download)
            }
            state.searchResults = results
        case .failure:
            // Local matches still show; the server search is a bonus.
            break
        }
        return .none
    }

    func handleDeleteResult(
        _ result: Result<String, Error>,
        state: inout State
    ) -> Effect<Action> {
        switch result {
        case .success(let videoId):
            removeDownload(videoId, state: &state)
        case .failure(let error):
            state.alert = .requestFailed(error)
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
        return .run { [clock, downloadService] send in
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
        let neighbourID: String?
        if nextIndex < state.downloads.endIndex {
            neighbourID = state.downloads[nextIndex].id
        } else if index > state.downloads.startIndex {
            let prevIndex = state.downloads.index(before: index)
            neighbourID = state.downloads[prevIndex].id
        } else {
            neighbourID = nil
        }
        guard let neighbourID else { return }
        state.scrollPositionID = neighbourID
        // tvOS: the focused card is about to vanish, which would drop focus
        // entirely; hand it to the card that takes its place.
        if state.focusedDownloadID == videoId || state.focusedDownloadID == nil {
            state.focusedDownloadID = neighbourID
        }
    }

    // MARK: - Private Handlers

    private func removeDownload(
        _ videoId: String,
        state: inout State
    ) {
        anchorScrollBeforeRemoval(of: videoId, state: &state)
        state.downloads.remove(id: videoId)
        state.searchResults.remove(id: videoId)
    }

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
            merge(response.data.reversed(), replacing: state.isLoading, state: &state)

        case .oldestFirst:
            merge(response.data, replacing: state.isLoading, state: &state)
        }

        state.currentPage = response.paginate.currentPage
        state.lastPage = discoveredLastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true

        // In newest-first mode we land on the final API page first. If that
        // page is only partially filled, the list is too short to scroll and
        // the last card's appearance never pages — so pre-fetch the previous
        // page to give the user a usable list out of the gate.
        if state.sortOrder == .newestFirst,
           response.paginate.currentPage == discoveredLastPage,
           response.paginate.currentPage > 1,
           response.data.count < 20 {
            state.isLoadingMore = true
            return fetchDownloads(
                config: state.serverConfig,
                page: response.paginate.currentPage - 1
            )
        }

        return .none
    }

    private func merge(
        _ page: some Sequence<DownloadResponse>,
        replacing: Bool,
        state: inout State
    ) {
        if replacing {
            state.downloads = []
        }
        for download in page {
            state.downloads.updateOrAppend(download)
        }
    }
}

extension AlertState where Action == DownloadsReducer.AlertAction {
    static func requestFailed(_ error: any Error) -> Self {
        AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(error.localizedDescription)
        }
    }
}
