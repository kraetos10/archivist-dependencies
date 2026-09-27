import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DownloadsReducer {
    public func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear, .pullToRefreshTriggered:
            // Every appearance re-fetches: tvOS has no pull-to-refresh, and
            // the optimistic removal on download-confirm can leave the list
            // empty while the server still has pending items.
            return handleRefresh(state: &state)
        case .itemAppeared(let id):
            // Page on the last *rendered* card — while searching, the
            // unfiltered buffer's last item isn't on screen.
            guard id == state.filteredDownloads.last?.id else { return .none }
            return handleLoadNextPage(state: &state)
        case .downloadTapped(let download):
            return handleDownloadTapped(download, state: &state)
        case .deleteTapped(let download):
            return handleDeleteTapped(download, state: &state)
        case .sortOrderChanged(let order):
            return handleSortOrderChanged(order, state: &state)
        }
    }

    /// Reloads from page one, superseding any page load in flight.
    func handleRefresh(state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.isLoadingMore = false
        state.currentPage = 1
        state.lastPage = 1
        return fetchDownloads(config: state.serverConfig, page: 1)
    }

    // MARK: - Private Handlers

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        guard !state.isLoading, !state.isLoadingMore else { return .none }
        switch state.sortOrder {
        case .newestFirst:
            guard state.currentPage > 1 else { return .none }
            state.isLoadingMore = true
            return fetchDownloads(config: state.serverConfig, page: state.currentPage - 1)
        case .oldestFirst:
            guard state.currentPage < state.lastPage else { return .none }
            state.isLoadingMore = true
            return fetchDownloads(config: state.serverConfig, page: state.currentPage + 1)
        }
    }

    private func handleSortOrderChanged(
        _ order: DownloadSortOrder,
        state: inout State
    ) -> Effect<Action> {
        guard order != state.sortOrder else { return .none }
        state.$sortOrder.withLock { $0 = order }
        state.downloads = []
        state.currentPage = 1
        state.lastPage = 1
        state.isLoading = true
        state.isLoadingMore = false
        state.hasLoaded = false
        return fetchDownloads(config: state.serverConfig, page: 1)
    }

    private func handleDownloadTapped(
        _ download: DownloadResponse,
        state: inout State
    ) -> Effect<Action> {
        #if os(tvOS)
        state.alert = AlertState {
            TextState(download.title ?? download.youtubeId)
        } actions: {
            ButtonState(action: .confirmDownload(download.youtubeId)) {
                TextState(String.localised("video.downloadNow", table: .videos))
            }
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
        } message: {
            TextState(String.localised("video.confirmDownload", table: .videos))
        }
        #else
        state.downloadDetail = DownloadDetailReducer.State(
            serverConfig: state.serverConfig,
            download: download
        )
        #endif
        return .none
    }

    private func handleDeleteTapped(
        _ download: DownloadResponse,
        state: inout State
    ) -> Effect<Action> {
        let config = state.serverConfig
        let videoId = download.youtubeId
        return .run { [downloadService] send in
            let result = await Result {
                try await downloadService.deleteDownload(config: config, id: videoId)
            }
            await send(.deleteResult(result.map { videoId }))
        }
    }

    func fetchDownloads(
        config: ServerConfig,
        page: Int
    ) -> Effect<Action> {
        .run { [downloadService] send in
            let result = await Result {
                try await downloadService.getDownloads(
                    config: config,
                    page: page,
                    filter: "pending",
                    channel: nil,
                    query: nil,
                    vidType: nil
                )
            }
            await send(.downloadsResult(result))
        }
        .cancellable(id: CancelID.fetch, cancelInFlight: true)
    }
}
