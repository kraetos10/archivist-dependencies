#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension TVSearchReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .searchSubmitted:
            return handleSearchSubmitted(state: &state)
        case .videoTapped(let video):
            return handleVideoTapped(video, state: &state)
        case .channelTapped(let channel):
            return handleChannelTapped(channel, state: &state)
        case .playlistTapped(let playlist):
            return handlePlaylistTapped(playlist, state: &state)
        case .markAsWatchedTapped(let video):
            return .send(.delegate(.markAsWatchedRequested(video)))
        case .deleteFromServerTapped(let video):
            return handleDeleteFromServerTapped(video, state: &state)
        }
    }

    func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.lastSearchedQuery = ""
            state.videoResults = []
            state.channelResults = []
            state.playlistResults = []
            state.hasSearched = false
            return .cancel(id: CancelID.search)
        }
        // Don't re-search if the query hasn't changed (e.g. focus moved)
        guard query != state.lastSearchedQuery else { return .none }
        return .run { [clock] send in
            try await clock.sleep(for: .milliseconds(600))
            await send(.view(.searchSubmitted))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handleSearchSubmitted(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .none }
        state.isSearching = true
        state.lastSearchedQuery = query
        let config = state.serverConfig
        return .run { [searchService] send in
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handleVideoTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true
        state.videoDetail = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: [],
            shouldAutoPlayNextVideo: autoPlayEnabled
        )
        return .none
    }

    private func handleChannelTapped(
        _ channel: ChannelResponse,
        state: inout State
    ) -> Effect<Action> {
        state.channelDetail = ChannelDetailReducer.State(
            serverConfig: state.serverConfig,
            channel: channel
        )
        return .none
    }

    private func handlePlaylistTapped(
        _ playlist: PlaylistResponse,
        state: inout State
    ) -> Effect<Action> {
        state.playlistDetail = PlaylistDetailReducer.State(
            serverConfig: state.serverConfig,
            playlist: playlist
        )
        return .none
    }

    /// Drops the result straight away — as the filtered video list does —
    /// since the parent performs the delete and never reports back.
    private func handleDeleteFromServerTapped(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        state.videoResults.removeAll { $0.videoId == video.videoId }
        return .send(.delegate(.deleteFromServerRequested(video)))
    }
}
#endif
