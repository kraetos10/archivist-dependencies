import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .channelsResult(.success(let response)):
            return handleChannelsLoaded(response, state: &state)
        case .channelsResult(.failure):
            return handleChannelsFailed(state: &state)
        case .addChannel(.presented(.subscribeResult(.success))):
            return handleSubscribeSucceeded(state: &state)
        case .searchResult(.success(let channels)):
            state.searchResults = IdentifiedArrayOf(uniqueElements: channels)
            state.isSearching = false
            return .none
        case .searchResult(.failure):
            state.isSearching = false
            return .none
        case .unsubscribeResult(.success(let channelId)):
            state.channels.remove(id: channelId)
            return .none
        case .unsubscribeResult(.failure):
            return .none
        default:
            return .none
        }
    }

    // MARK: - Private Handlers

    private func handleChannelsLoaded(_ response: PaginatedResponse<ChannelResponse>, state: inout State) -> Effect<Action> {
        if state.isLoading {
            state.channels = IdentifiedArrayOf(uniqueElements: response.data)
        } else {
            for channel in response.data {
                state.channels.updateOrAppend(channel)
            }
        }
        state.currentPage = response.paginate.currentPage
        state.lastPage = response.paginate.lastPage
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }

    private func handleChannelsFailed(state: inout State) -> Effect<Action> {
        state.isLoading = false
        state.isLoadingMore = false
        state.hasLoaded = true
        return .none
    }

    public func handleSearchQueryChanged(state: inout State) -> Effect<Action> {
        let query = state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state.searchResults = []
            state.isSearching = false
            return .cancel(id: CancelID.search)
        }
        state.isSearching = true
        let config = state.serverConfig
        let clock = self.clock
        let searchService = self.searchService
        return .run { send in
            try await clock.sleep(for: .milliseconds(400))
            let result = await Result {
                try await searchService.search(config: config, query: query)
            }
            await send(.searchResult(result.map { $0.channelResults ?? [] }))
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handleSubscribeSucceeded(state: inout State) -> Effect<Action> {
        state.addChannel = nil
        return .send(.view(.pullToRefreshTriggered))
    }
}
