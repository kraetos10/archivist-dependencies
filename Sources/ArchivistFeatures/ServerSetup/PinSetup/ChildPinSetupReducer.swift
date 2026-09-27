import ComposableArchitecture

/// Presentation domain for the child-mode PIN setup sheet. The sheet owns
/// its own text entry; this only reports the outcome, which the presenting
/// feature handles (saving the PIN, or turning the toggle back off).
@Reducer
public struct ChildPinSetupReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public init() {}
    }

    public enum Action: Sendable {
        case confirmed(String)
        case cancelled
    }

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
