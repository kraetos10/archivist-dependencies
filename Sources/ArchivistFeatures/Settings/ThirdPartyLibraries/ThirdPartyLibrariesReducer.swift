import ComposableArchitecture
import Foundation

@Reducer
public struct ThirdPartyLibrariesReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public var libraries: [ThirdPartyLibrary] = ThirdPartyLibrary.bundled

        public init() {}
    }

    public enum Action: ViewAction {
        case view(View)

        @CasePathable
        public enum View {
            case viewDidAppear
        }
    }

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            }
        }
    }
}

public struct ThirdPartyLibrary: Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let license: String
    public let url: URL?

    public init(name: String, license: String, url: URL?) {
        self.name = name
        self.license = license
        self.url = url
    }

    static let bundled: [ThirdPartyLibrary] = [
        ThirdPartyLibrary(
            name: "VLCKit",
            license: "LGPL-2.1",
            url: URL(string: "https://code.videolan.org/videolan/VLCKit")
        )
    ]
}
