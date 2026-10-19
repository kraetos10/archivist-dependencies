#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DiscoverSetupReducer {
    func handleVerifyResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isVerifying = false
        switch result {
        case .success:
            return saveKey(state: &state)
        case .failure(let error):
            switch error as? YouTubeError {
            // Over quota means YouTube recognised the key and the API is on:
            // the key is good, it just has nothing left to spend today.
            case .quotaExceeded:
                return saveKey(state: &state)
            case .invalidKey:
                state.failure = .invalidKey
            case .apiNotEnabled:
                state.failure = .apiNotEnabled
            case .network:
                state.failure = .network
            default:
                state.failure = .unexpected
            }
            return .none
        }
    }

    private func saveKey(state: inout State) -> Effect<Action> {
        let key = state.trimmedKey
        do {
            try youTubeAPIKeyStore.save(key)
        } catch {
            state.failure = .unexpected
            return .none
        }
        return .send(.delegate(.keySaved(key)))
    }
}
#endif
