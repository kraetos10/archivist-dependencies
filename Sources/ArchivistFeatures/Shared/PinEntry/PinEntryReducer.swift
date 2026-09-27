import ComposableArchitecture

/// Presentation domain for the child-mode PIN entry sheet. The presenter
/// loads the PIN from `PinStore` and hands it in, so the sheet never reads
/// storage itself; the outcome goes back to the presenter.
@Reducer
public struct PinEntryReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public var expectedPin: String

        public init(expectedPin: String) {
            self.expectedPin = expectedPin
        }
    }

    public enum Action: Sendable {
        case succeeded
        case cancelled
    }

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }
}
