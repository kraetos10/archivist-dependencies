#if !os(watchOS)
import ArchivistComponents
import ComposableArchitecture
import Foundation

extension PlaybackCacheReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return refreshStats()
        case .clearCacheTapped:
            return .run { send in
                let (size, count) = await MainActor.run { () -> (Int64, Int) in
                    PlaybackCache.shared.clearAll()
                    return (PlaybackCache.shared.totalSize(), PlaybackCache.shared.entries().count)
                }
                await send(.cacheStatsLoaded(totalSize: size, entryCount: count))
            }
        }
    }

    func refreshStats() -> Effect<Action> {
        .run { send in
            let (size, count) = await MainActor.run { () -> (Int64, Int) in
                (PlaybackCache.shared.totalSize(), PlaybackCache.shared.entries().count)
            }
            await send(.cacheStatsLoaded(totalSize: size, entryCount: count))
        }
    }
}
#endif
