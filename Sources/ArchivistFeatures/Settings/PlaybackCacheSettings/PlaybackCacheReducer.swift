#if !os(watchOS)
import ArchivistComponents
import ComposableArchitecture
import Foundation

@Reducer
public struct PlaybackCacheReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        var totalSize: Int64 = 0
        var entryCount: Int = 0
        @Shared(.appStorage("vlcPrebufferToDisk")) public var prebufferEnabled = PlaybackCache.defaultPrebufferEnabled
        @Shared(.appStorage("prebufferWifiOnly")) public var prebufferWifiOnly = PlaybackCache.defaultPrebufferWifiOnly
        @Shared(.appStorage("playbackCacheSizeLimitBytes")) public var cacheSizeLimitBytes = PlaybackCache.defaultCacheSizeLimitBytes

        public init() {}
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case cacheStatsLoaded(totalSize: Int64, entryCount: Int)

        @CasePathable
        public enum View {
            case viewDidAppear
            case clearCacheTapped
        }
    }

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            default:
                return handleInternalAction(action, state: &state)
            }
        }
    }
}
#endif
