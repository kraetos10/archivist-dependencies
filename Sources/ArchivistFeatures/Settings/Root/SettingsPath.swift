import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum SettingsPath {
    case downloads(DownloadsReducer)
    case stats(StatsReducer)
    case history(HistoryReducer)
    #if !os(watchOS)
    case playbackCache(PlaybackCacheReducer)
    #endif
    #if !os(tvOS)
    case thirdPartyLibraries(ThirdPartyLibrariesReducer)
    #endif
}

extension SettingsPath.State: Sendable {}
