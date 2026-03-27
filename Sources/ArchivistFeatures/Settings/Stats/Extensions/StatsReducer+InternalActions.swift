import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension StatsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .videoStatsLoaded(let video):
            state.videoStats = video
            state.loadedSections.insert(.video)
            return checkAllLoaded(state: &state)
        case .channelStatsLoaded(let channel):
            state.channelStats = channel
            state.loadedSections.insert(.channel)
            return checkAllLoaded(state: &state)
        case .playlistStatsLoaded(let playlist):
            state.playlistStats = playlist
            state.loadedSections.insert(.playlist)
            return checkAllLoaded(state: &state)
        case .downloadStatsLoaded(let download):
            state.downloadStats = download
            state.loadedSections.insert(.download)
            return checkAllLoaded(state: &state)
        case .watchStatsLoaded(let watch):
            state.watchStats = watch
            state.loadedSections.insert(.watch)
            return checkAllLoaded(state: &state)
        case .biggestChannelsLoaded(let channels):
            state.biggestChannels = channels
            state.loadedSections.insert(.biggestChannels)
            return checkAllLoaded(state: &state)
        case .statsFailed(let section):
            state.loadedSections.insert(section)
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
