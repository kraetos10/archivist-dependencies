import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoPickerReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .videoToggled(let item):
            if let index = state.selectedVideoIds.firstIndex(of: item.id) {
                state.selectedVideoIds.remove(at: index)
            } else {
                state.selectedVideoIds.append(item.id)
            }
            return .none
        case .addTapped:
            return handleAddTapped(state: &state)
        case .lastItemAppeared:
            return handleLastItemAppeared(state: &state)
        }
    }

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        guard !state.hasLoaded, !state.isLoading else { return .none }
        state.isLoading = true
        state.isLoadingDownloads = true
        let config = state.serverConfig
        let downloadService = self.downloadService
        return .merge(
            fetchVideos(page: 1, config: config),
            .run { send in
                let result = await Result {
                    try await downloadService.getDownloads(
                        config: config,
                        page: 1,
                        filter: "pending",
                        channel: nil,
                        query: nil,
                        vidType: nil
                    )
                }
                await send(.downloadsResult(result))
            }
        )
    }

    private func handleLastItemAppeared(state: inout State) -> Effect<Action> {
        guard !state.isSearchActive,
              state.currentPage < state.lastPage,
              !state.isLoadingMore else { return .none }
        state.isLoadingMore = true
        return fetchVideos(page: state.currentPage + 1, config: state.serverConfig)
    }

    private func fetchVideos(
        page: Int,
        config: ServerConfig
    ) -> Effect<Action> {
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: page,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: nil,
                    playlist: nil
                )
            }
            await send(.videosResult(result))
        }
    }

    /// Adds the picked videos one at a time, in the order they were picked,
    /// so they land in the playlist in that order and the server never sees
    /// concurrent edits to the same playlist.
    private func handleAddTapped(state: inout State) -> Effect<Action> {
        guard !state.selectedVideoIds.isEmpty, !state.isAdding else { return .none }
        state.isAdding = true
        let config = state.serverConfig
        let playlistId = state.playlistId
        let videoIds = state.selectedVideoIds
        let playlistService = self.playlistService
        return .run { send in
            var failed: [String] = []
            for videoId in videoIds {
                do {
                    try await playlistService.modifyCustomPlaylist(
                        config: config,
                        id: playlistId,
                        action: "create",
                        videoId: videoId
                    )
                } catch {
                    failed.append(videoId)
                }
            }
            await send(.addFinished(failedIds: failed))
        }
    }

    func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.searchResults = []
            state.isSearching = false
            state.updateDisplayedItems()
            return .cancel(id: CancelID.search)
        }
        state.isSearching = true
        // Local matches show straight away; server results merge in later.
        state.updateDisplayedItems()
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
}
