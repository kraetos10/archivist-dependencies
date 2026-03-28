#if !os(watchOS)
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension PlaybackCacheReducer {
    func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .cacheStatsLoaded(let totalSize, let entryCount):
            state.totalSize = totalSize
            state.entryCount = entryCount
            return .none
        default:
            return .none
        }
    }
}
#endif
