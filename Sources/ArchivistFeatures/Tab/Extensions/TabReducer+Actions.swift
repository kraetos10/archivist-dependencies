import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture

extension TabReducer {
    func handleAppeared(state: inout State) -> Effect<Action> {
        .merge(
            .send(.settings(.activeTask(.view(.startPolling)))),
            .run { [pipRestoreService] send in
                for await requested in await pipRestoreService.subscribe() {
                    guard requested else { continue }
                    await pipRestoreService.consume()
                    await send(.miniPlayerTapped)
                }
            }
        )
    }

    func handleShowMiniPlayer(
        _ video: VideoResponse,
        _ nextVideos: [VideoResponse],
        _ config: ServerConfig,
        _ showPlayNext: Bool,
        state: inout State
    ) -> Effect<Action> {
        state.miniPlayer = MiniPlayerState(
            video: video,
            serverConfig: config,
            nextVideos: nextVideos,
            showPlayNext: showPlayNext
        )
        return .none
    }

    func handleMiniPlayerTapped(state: inout State) -> Effect<Action> {
        guard let mini = state.miniPlayer else { return .none }
        state.miniPlayer = nil
        state.selectedTab = .home
        state.videoList.videoDetail = VideoDetailReducer.State(
            serverConfig: mini.serverConfig,
            video: mini.video,
            nextVideos: mini.nextVideos,
            showPlayNext: mini.showPlayNext,
            isPlaying: true
        )
        return .run { _ in
            await MainActor.run {
                #if !os(tvOS)
                PlayerManager.shared.stopPiP()
                #endif
                PlayerManager.shared.resume()
            }
        }
    }

    func handleMiniPlayerPlayPauseTapped(state: inout State) -> Effect<Action> {
        .run { _ in
            await MainActor.run {
                PlayerManager.shared.togglePlayPause()
            }
        }
    }

    func handleMiniPlayerCloseTapped(state: inout State) -> Effect<Action> {
        state.miniPlayer = nil
        return .run { _ in
            await MainActor.run {
                PlayerManager.shared.stop()
            }
        }
    }
}
