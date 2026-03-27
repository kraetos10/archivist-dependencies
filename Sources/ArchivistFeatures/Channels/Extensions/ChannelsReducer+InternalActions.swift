import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension ChannelsReducer {
    public func handleInternalAction(_ action: Action, state: inout State) -> Effect<Action> {
        switch action {
        case .channelsLoaded(let response):
            return handleChannelsLoaded(response, state: &state)
        case .channelsFailed:
            return handleChannelsFailed(state: &state)
        case .addChannel(.presented(.subscribeSucceeded)):
            return handleSubscribeSucceeded(state: &state)
        case .searchResultsLoaded(let channels):
            state.searchResults = IdentifiedArrayOf(uniqueElements: channels)
            state.isSearching = false
            return .none
        case .searchFailed:
            state.isSearching = false
            return .none
        case .unsubscribeCompleted(let channelId):
            state.channels.remove(id: channelId)
            return .none
        case .unsubscribeFailed:
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
            do {
                let response = try await searchService.search(config: config, query: query)
                await send(.searchResultsLoaded(response.channelResults ?? []))
            } catch {
                await send(.searchFailed)
            }
        }
        .cancellable(id: CancelID.search, cancelInFlight: true)
    }

    private func handleSubscribeSucceeded(state: inout State) -> Effect<Action> {
        state.addChannel = nil
        return .send(.view(.pullToRefreshTriggered))
    }
}
