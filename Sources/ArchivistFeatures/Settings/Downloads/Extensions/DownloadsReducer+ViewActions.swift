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
        case .viewDidAppear:
            return handleOnAppear(state: &state)
        case .pullToRefreshTriggered:
            return handleRefreshTriggered(state: &state)
        case .lastItemAppeared:
            return handleLoadNextPage(state: &state)
        case .downloadTapped(let download):
            return handleDownloadTapped(download, state: &state)
        case .deleteTapped(let download):
            return handleDeleteTapped(download, state: &state)
        case .sortOrderChanged(let order):
            return handleSortOrderChanged(order, state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleOnAppear(state: inout State) -> Effect<Action> {
        guard state.downloads.isEmpty, !state.isLoading else { return .none }
        state.isLoading = true
        return fetchDownloads(config: state.serverConfig, page: 1)
    }

    private func handleRefreshTriggered(state: inout State) -> Effect<Action> {
        guard !state.isLoading else { return .none }
        state.isLoading = true
        state.currentPage = 1
        state.lastPage = 1
        return fetchDownloads(config: state.serverConfig, page: 1)
    }

    private func handleLoadNextPage(state: inout State) -> Effect<Action> {
        switch state.sortOrder {
        case .newestFirst:
            guard state.currentPage > 1, !state.isLoadingMore else { return .none }
            state.isLoadingMore = true
            return fetchDownloads(config: state.serverConfig, page: state.currentPage - 1)
        case .oldestFirst:
            guard state.currentPage < state.lastPage, !state.isLoadingMore else { return .none }
            state.isLoadingMore = true
            return fetchDownloads(config: state.serverConfig, page: state.currentPage + 1)
        }
    }

    private func handleSortOrderChanged(
        _ order: DownloadSortOrder,
        state: inout State
    ) -> Effect<Action> {
        guard order != state.sortOrder else { return .none }
        state.sortOrder = order
        state.downloads = []
        state.currentPage = 1
        state.lastPage = 1
        state.isLoading = true
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
        let downloadService = self.downloadService
        return .run { send in
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
        let downloadService = self.downloadService
        return .run { send in
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
    }
}
