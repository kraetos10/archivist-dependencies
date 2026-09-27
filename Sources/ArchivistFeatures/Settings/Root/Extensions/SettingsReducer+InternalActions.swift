import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension SettingsReducer {
    /// A server download finished: refresh the queue screen if it's on the
    /// stack. Walks from the top so the one the user is looking at wins.
    func handleDownloadCompleted(state: inout State) -> Effect<Action> {
        for (id, element) in zip(state.path.ids, state.path).reversed() {
            if case .downloads = element {
                return .send(.path(.element(id: id, action: .downloads(.refresh))))
            }
        }
        return .none
    }

    func handleRescanResult(
        _ result: Result<Void, Error>,
        state: inout State
    ) -> Effect<Action> {
        state.isRescanningSubscriptions = false
        switch result {
        case .success:
            return .send(.activeTask(.startPolling))
        case .failure(let error):
            state.alert = AlertState {
                TextState(String.localised("settings.rescanFailed", table: .settings))
            } message: {
                TextState(error.localizedDescription)
            }
            return .none
        }
    }
}
