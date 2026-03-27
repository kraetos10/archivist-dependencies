import ArchivistNetworking
import ComposableArchitecture
import Foundation
import SwiftUI

extension PlaylistDetailReducer {
    public func handleViewAction(_ action: Action.View, state: inout State) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return handleViewDidAppear(state: &state)
        case .entryTapped(let entry):
            return handleEntryTapped(entry, state: &state)
        case .dismissTapped:
            return .none
        case .unsubscribeTapped:
            return handleUnsubscribeTapped(state: &state)
        case .removeEntryTapped(let entry):
            return handleRemoveEntryTapped(entry, state: &state)
        case .moveEntry(let source, let destination):
            return handleMoveEntry(source: source, destination: destination, state: &state)
        case .editTapped:
            state.isEditing.toggle()
            return .none
        case .addVideoTapped:
            state.videoPicker = VideoPickerReducer.State(
                serverConfig: state.serverConfig,
                playlistId: state.playlist.playlistId
            )
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleViewDidAppear(state: inout State) -> Effect<Action> {
        guard !state.hasLoadedEntries, !state.isLoadingEntries else { return .none }
        state.isLoadingEntries = true
        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        let playlistService = self.playlistService
        return .run { send in
            do {
                let playlist = try await playlistService.getPlaylist(config: config, id: playlistId)
                await send(.playlistLoaded(playlist))
            } catch {
                await send(.playlistFailed(error))
            }
        }
    }

    private func handleUnsubscribeTapped(state: inout State) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String(localized: "Remove Playlist"))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String(localized: "Cancel"))
            }
            ButtonState(role: .destructive, action: .confirmUnsubscribe) {
                TextState(String(localized: "Remove"))
            }
        } message: { [state] in
            TextState(String(localized: "Are you sure you want to remove \(state.playlist.playlistName)?"))
        }
        return .none
    }

    private func handleEntryTapped(_ entry: PlaylistEntry, state: inout State) -> Effect<Action> {
        guard let videoId = entry.youtubeId else { return .none }
        let config = state.serverConfig
        let entries = state.entries
        let tappedIndex = entries.firstIndex(where: { $0.youtubeId == videoId })
        let nextEntryIds: [String] = {
            guard let idx = tappedIndex else { return [] }
            return entries.suffix(from: entries.index(after: idx)).compactMap(\.youtubeId)
        }()
        let videoService = self.videoService
        return .run { send in
            let video = try await videoService.getVideo(config: config, id: videoId)
            let nextVideos: [VideoResponse] = await withTaskGroup(of: VideoResponse?.self) { group in
                for nextId in nextEntryIds.prefix(10) {
                    group.addTask {
                        try? await videoService.getVideo(config: config, id: nextId)
                    }
                }
                var results: [(Int, VideoResponse)] = []
                for await result in group {
                    if let video = result,
                       let order = nextEntryIds.firstIndex(of: video.videoId) {
                        results.append((order, video))
                    }
                }
                return results.sorted { $0.0 < $1.0 }.map(\.1)
            }
            await send(.videoLoaded(video, nextVideos: nextVideos))
        } catch: { error, send in
            await send(.videoFailed(error))
        }
    }

    private func handleRemoveEntryTapped(_ entry: PlaylistEntry, state: inout State) -> Effect<Action> {
        guard let videoId = entry.youtubeId, state.isCustomPlaylist else { return .none }
        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        let playlistService = self.playlistService
        return .run { send in
            do {
                try await playlistService.modifyCustomPlaylist(
                    config: config,
                    id: playlistId,
                    action: "remove",
                    videoId: videoId
                )
                await send(.removeEntryCompleted(videoId))
            } catch {
                await send(.removeEntryFailed)
            }
        }
    }

    private func handleMoveEntry(source: IndexSet, destination: Int, state: inout State) -> Effect<Action> {
        guard state.isCustomPlaylist,
              let sourceIndex = source.first,
              sourceIndex < state.entries.count,
              let videoId = state.entries[sourceIndex].youtubeId else { return .none }

        let newPosition = destination > sourceIndex ? destination - 1 : destination

        var entries = state.entries
        entries.move(fromOffsets: source, toOffset: destination)
        state.playlist = state.playlist.withEntries(entries)

        let config = state.serverConfig
        let playlistId = state.playlist.playlistId
        let playlistService = self.playlistService

        return .run { send in
            do {
                try await playlistService.modifyCustomPlaylist(
                    config: config,
                    id: playlistId,
                    action: "move",
                    videoId: videoId,
                    position: newPosition
                )
            } catch {
                await send(.moveEntryFailed)
            }
        }
    }
}
