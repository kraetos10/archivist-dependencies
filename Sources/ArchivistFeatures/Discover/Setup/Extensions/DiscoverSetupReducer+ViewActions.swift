#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DiscoverSetupReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .nextTapped:
            return handleNextTapped(state: &state)
        case .backTapped:
            return handleBackTapped(state: &state)
        case .openLinkTapped(let link):
            return handleOpenLinkTapped(link)
        case .pasted(let text):
            return handlePasted(text, state: &state)
        case .verifyTapped:
            return handleVerifyTapped(state: &state)
        case .closeTapped:
            return .send(.delegate(.cancelled))
        }
    }

    func handleNextTapped(state: inout State) -> Effect<Action> {
        guard let next = State.Step(rawValue: state.step.rawValue + 1) else { return .none }
        state.step = next
        return .none
    }

    func handleBackTapped(state: inout State) -> Effect<Action> {
        guard let previous = State.Step(rawValue: state.step.rawValue - 1) else { return .none }
        state.step = previous
        state.failure = nil
        return .none
    }

    func handleOpenLinkTapped(_ link: Link) -> Effect<Action> {
        guard let url = link.url else { return .none }
        return .run { [openURL] _ in
            await openURL(url)
        }
    }

    func handlePasted(
        _ text: String,
        state: inout State
    ) -> Effect<Action> {
        state.keyInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        state.failure = nil
        return .none
    }

    func handleVerifyTapped(state: inout State) -> Effect<Action> {
        guard state.canVerify else { return .none }
        state.isVerifying = true
        state.failure = nil
        let key = state.trimmedKey
        return .run { [youTubeSearchService] send in
            let result = await Result {
                try await youTubeSearchService.validateKey(key: key)
            }
            await send(.verifyResult(result))
        }
    }
}
#endif
