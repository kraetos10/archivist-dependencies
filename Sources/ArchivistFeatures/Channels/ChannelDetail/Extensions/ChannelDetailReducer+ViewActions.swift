import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelDetailReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .lastVideoAppeared:
            return handleLastVideoAppeared(state: &state)
        case .videoCardTapped(let video):
            return handleVideoCardTapped(video, state: &state)
        case .downloadCardTapped(let download):
            return handleDownloadCardTapped(download, state: &state)
        case .unsubscribeTapped:
            return handleUnsubscribeTapped(state: &state)
        case .descriptionToggleTapped:
            return handleDescriptionToggleTapped(state: &state)
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        let config = state.serverConfig
        let channelId = state.channel.channelId

        var effects: [Effect<Action>] = []

        if state.videos.isEmpty, !state.isLoadingVideos {
            state.isLoadingVideos = true
            effects.append(
                .run { send in
                    do {
                        let response = try await videoService.getVideos(
                            config: config,
                            page: 1,
                            sort: "published",
                            order: "desc",
                            type: nil,
                            watch: nil,
                            channel: channelId,
                            playlist: nil
                        )
                        await send(.videosLoaded(response))
                    } catch {
                        await send(.videosFailed(error))
                    }
                }
            )
        }

        if state.pendingDownloads.isEmpty, !state.isLoadingDownloads {
            state.isLoadingDownloads = true
            effects.append(
                .run { send in
                    do {
                        let response = try await downloadService.getDownloads(
                            config: config,
                            page: 1,
                            filter: "pending",
                            channel: channelId,
                            query: nil,
                            vidType: nil
                        )
                        await send(.downloadsLoaded(response))
                    } catch {
                        await send(.downloadsFailed(error))
                    }
                }
            )
        }

        return .merge(effects)
    }

    private func handleLastVideoAppeared(state: inout State) -> Effect<Action> {
        guard state.currentPage < state.lastPage, !state.isLoadingMoreVideos else { return .none }
        state.isLoadingMoreVideos = true
        let config = state.serverConfig
        let channelId = state.channel.channelId
        let nextPage = state.currentPage + 1
        return .run { send in
            do {
                let response = try await videoService.getVideos(
                    config: config,
                    page: nextPage,
                    sort: "published",
                    order: "desc",
                    type: nil,
                    watch: nil,
                    channel: channelId,
                    playlist: nil
                )
                await send(.videosLoaded(response))
            } catch {
                await send(.videosFailed(error))
            }
        }
    }

    private func handleVideoCardTapped(_ video: VideoResponse, state: inout State) -> Effect<Action> {
        let nextVideos: [VideoResponse]
        if let index = state.videos.firstIndex(where: { $0.id == video.id }) {
            nextVideos = Array(state.videos.suffix(from: state.videos.index(after: index)).filter { !$0.isWatched })
        } else {
            nextVideos = []
        }
        return .send(.delegate(.videoSelected(video, nextVideos: nextVideos)))
    }

    private func handleDownloadCardTapped(_ download: DownloadResponse, state: inout State) -> Effect<Action> {
        #if os(tvOS)
        state.alert = AlertState {
            TextState(download.title ?? download.youtubeId)
        } actions: {
            ButtonState(action: .confirmDownload(download.youtubeId)) {
                TextState(String.localised("video.downloadNow", table: .videos))
            }
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel"))
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

    private func handleUnsubscribeTapped(state: inout State) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String.localised("generic.unsubscribe"))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel"))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe) {
                TextState(String.localised("generic.unsubscribe"))
            }
        } message: { [state] in
            TextState(String.localised("Are you sure you want to unsubscribe from \(state.channel.channelName)?", table: .login))
        }
        return .none
    }

    private func handleDescriptionToggleTapped(state: inout State) -> Effect<Action> {
        state.isDescriptionExpanded.toggle()
        return .none
    }
}
