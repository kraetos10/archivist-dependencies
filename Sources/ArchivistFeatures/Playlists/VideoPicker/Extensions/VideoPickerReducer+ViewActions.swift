import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension VideoPickerReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .videoToggled(let item):
            if state.selectedVideoIds.contains(item.id) {
                state.selectedVideoIds.remove(item.id)
            } else {
                state.selectedVideoIds.insert(item.id)
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
        let videoService = self.videoService
        let downloadService = self.downloadService
        return .merge(
            .run { send in
                let result = await Result {
                    try await videoService.getVideos(
                        config: config,
                        page: 1,
                        sort: "published",
                        order: "desc",
                        type: nil,
                        watch: nil,
                        channel: nil,
                        playlist: nil
                    )
                }
                await send(.videosResult(result))
            },
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
        let config = state.serverConfig
        let nextPage = state.currentPage + 1
        let videoService = self.videoService
        return .run { send in
            let result = await Result {
                try await videoService.getVideos(
                    config: config,
                    page: nextPage,
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

    private func handleAddTapped(state: inout State) -> Effect<Action> {
        guard !state.selectedVideoIds.isEmpty, !state.isAdding else { return .none }
        state.isAdding = true
        let config = state.serverConfig
        let playlistId = state.playlistId
        let videoIds = Array(state.selectedVideoIds)
        let playlistService = self.playlistService
        return .run { send in
            let result = await Result {
                for videoId in videoIds {
                    try await playlistService.modifyCustomPlaylist(
                        config: config,
                        id: playlistId,
                        action: "create",
                        videoId: videoId
                    )
                }
            }
            await send(.addResult(result))
        }
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
}
