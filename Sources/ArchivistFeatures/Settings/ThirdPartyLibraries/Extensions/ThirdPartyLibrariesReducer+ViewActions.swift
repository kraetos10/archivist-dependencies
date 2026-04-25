import ComposableArchitecture

extension ThirdPartyLibrariesReducer {
    func handleViewAction(
        _ action: Action.View,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .viewDidAppear:
            return .none
        }
    }
}
