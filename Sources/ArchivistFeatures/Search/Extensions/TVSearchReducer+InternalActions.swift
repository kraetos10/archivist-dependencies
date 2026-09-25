#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension TVSearchReducer {
    func handleSearchResult(
        _ result: Result<SearchResponse, Error>,
        state: inout State
    ) -> Effect<Action> {
        if case .success(let response) = result {
            state.videoResults = response.videoResults ?? []
            state.channelResults = response.channelResults ?? []
            state.playlistResults = response.playlistResults ?? []
        }
        state.isSearching = false
        state.hasSearched = true
        return .none
    }

    func handleChannelVideoSelected(
        _ video: VideoResponse,
        nextVideos: [VideoResponse],
        state: inout State
    ) -> Effect<Action> {
        @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true
        state.nestedVideoDetail = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: nextVideos,
            shouldAutoPlayNextVideo: autoPlayEnabled
        )
        return .none
    }

    func handlePlaylistVideoSelected(
        _ video: VideoResponse,
        nextVideos: [VideoResponse],
        loopVideoIds: [String],
        state: inout State
    ) -> Effect<Action> {
        @Shared(.appStorage("autoPlayPlaylist")) var autoPlayPlaylist = true
        state.nestedVideoDetail = VideoDetailReducer.State(
            serverConfig: state.serverConfig,
            video: video,
            nextVideos: nextVideos,
            loopVideoIds: loopVideoIds,
            shouldAutoPlayNextVideo: autoPlayPlaylist
        )
        return .none
    }

    func handleVideoUpdated(
        _ video: VideoResponse,
        state: inout State
    ) -> Effect<Action> {
        guard let index = state.videoResults.firstIndex(where: { $0.videoId == video.videoId })
        else { return .none }
        state.videoResults[index] = video
        return .none
    }

    func handleRefreshPendingDownloads(state: inout State) -> Effect<Action> {
        guard state.channelDetail != nil else { return .none }
        return .send(.channelDetail(.presented(.view(.viewDidAppear))))
    }
}
#endif
