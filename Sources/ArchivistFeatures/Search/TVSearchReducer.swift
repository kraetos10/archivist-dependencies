#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

@Reducer
public struct TVSearchReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        var serverConfig: ServerConfig
        var searchQuery: String = ""
        var videoResults: [VideoResponse] = []
        var channelResults: [ChannelResponse] = []
        var playlistResults: [PlaylistResponse] = []
        var isSearching = false
        var hasSearched = false
        var lastSearchedQuery: String = ""
        @Presents var videoDetail: VideoDetailReducer.State?
    }

    public enum Action: ViewAction, BindableAction {
        case view(View)
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case searchResult(Result<SearchResponse, Error>)
        case videoDetail(PresentationAction<VideoDetailReducer.Action>)

        @CasePathable
        public enum View {
            case searchSubmitted
            case videoTapped(VideoResponse)
            case channelTapped(ChannelResponse)
            case playlistTapped(PlaylistResponse)
        }

        @CasePathable
        public enum Delegate: Equatable, Sendable {
            case showChannel(ChannelResponse)
            case showPlaylist(PlaylistResponse)
        }
    }

    enum CancelID { case search }

    @Dependency(\.searchService) var searchService
    @Dependency(\.continuousClock) var clock

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.searchQuery):
                return handleSearchQueryChanged(state: &state)
            case .binding:
                return .none
            case .view(.searchSubmitted):
                return performSearch(state: &state)
            case .view(.videoTapped(let video)):
                @Shared(.appStorage("autoPlayEnabled")) var autoPlayEnabled = true
                state.videoDetail = VideoDetailReducer.State(
                    serverConfig: state.serverConfig,
                    video: video,
                    nextVideos: [],
                    shouldAutoPlayNextVideo: autoPlayEnabled
                )
                return .none
            case .view(.channelTapped(let channel)):
                return .send(.delegate(.showChannel(channel)))
            case .view(.playlistTapped(let playlist)):
                return .send(.delegate(.showPlaylist(playlist)))
            case .videoDetail(.presented(.delegate(.didRequestMinimize))):
                state.videoDetail = nil
                return .none
            case .videoDetail(.presented(.delegate(.didDismiss))):
                state.videoDetail = nil
                return .none
            case .videoDetail:
                return .none
            case .delegate:
                return .none
            case .searchResult(.success(let response)):
                state.videoResults = response.videoResults ?? []
                state.channelResults = response.channelResults ?? []
                state.playlistResults = response.playlistResults ?? []
                state.isSearching = false
                state.hasSearched = true
                return .none
            case .searchResult(.failure):
                state.isSearching = false
                state.hasSearched = true
                return .none
            }
        }
        .ifLet(\.$videoDetail, action: \.videoDetail) {
            VideoDetailReducer()
        }
    }

    private func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.lastSearchedQuery = ""
            state.videoResults = []
            state.channelResults = []
            state.playlistResults = []
            state.hasSearched = false
            return .cancel(id: CancelID.search)
        }
        // Don't re-search if the query hasn't changed (e.g. focus moved)
        guard query != state.lastSearchedQuery else { return .none }
        return .run { [clock] send in
            try await clock.sleep(for: .milliseconds(600))
            await send(.view(.searchSubmitted))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func performSearch(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return .none }
        state.isSearching = true
        state.lastSearchedQuery = query
        let config = state.serverConfig
        return .run { [searchService] send in
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }
}
#endif
