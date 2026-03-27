import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension StatsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videoStatsResult(.success(let video)):
            state.videoStats = video
            state.loadedSections.insert(.video)
            return checkAllLoaded(state: &state)
        case .videoStatsResult(.failure):
            state.loadedSections.insert(.video)
            return checkAllLoaded(state: &state)
        case .channelStatsResult(.success(let channel)):
            state.channelStats = channel
            state.loadedSections.insert(.channel)
            return checkAllLoaded(state: &state)
        case .channelStatsResult(.failure):
            state.loadedSections.insert(.channel)
            return checkAllLoaded(state: &state)
        case .playlistStatsResult(.success(let playlist)):
            state.playlistStats = playlist
            state.loadedSections.insert(.playlist)
            return checkAllLoaded(state: &state)
        case .playlistStatsResult(.failure):
            state.loadedSections.insert(.playlist)
            return checkAllLoaded(state: &state)
        case .downloadStatsResult(.success(let download)):
            state.downloadStats = download
            state.loadedSections.insert(.download)
            return checkAllLoaded(state: &state)
        case .downloadStatsResult(.failure):
            state.loadedSections.insert(.download)
            return checkAllLoaded(state: &state)
        case .watchStatsResult(.success(let watch)):
            state.watchStats = watch
            state.loadedSections.insert(.watch)
            return checkAllLoaded(state: &state)
        case .watchStatsResult(.failure):
            state.loadedSections.insert(.watch)
            return checkAllLoaded(state: &state)
        case .biggestChannelsResult(.success(let channels)):
            state.biggestChannels = channels
            state.loadedSections.insert(.biggestChannels)
            return checkAllLoaded(state: &state)
        case .biggestChannelsResult(.failure):
            state.loadedSections.insert(.biggestChannels)
            return checkAllLoaded(state: &state)
        default:
            return .none
        }
    }

    // MARK: - Private Helpers

    private func checkAllLoaded(state: inout State) -> Effect<Action> {
        let allSections: Set<StatsSection> = [.video, .channel, .playlist, .download, .watch, .biggestChannels]
        if state.loadedSections == allSections {
            state.isLoading = false
        }
        state.hasLoaded = true
        return .none
    }
}
