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
        ),
        ThirdPartyLibrary(
            name: "VLC for iOS (player UI)",
            license: "GPL-2.0-or-later",
            url: URL(string: "https://code.videolan.org/videolan/vlc-ios")
        ),
        ThirdPartyLibrary(
            name: "swift-composable-architecture",
            license: "MIT",
            url: URL(string: "https://github.com/pointfreeco/swift-composable-architecture")
        ),
        ThirdPartyLibrary(
            name: "swift-dependencies",
            license: "MIT",
            url: URL(string: "https://github.com/pointfreeco/swift-dependencies")
        ),
        ThirdPartyLibrary(
            name: "swift-identified-collections",
            license: "MIT",
            url: URL(string: "https://github.com/pointfreeco/swift-identified-collections")
        ),
        ThirdPartyLibrary(
            name: "sqlite-data",
            license: "MIT",
            url: URL(string: "https://github.com/pointfreeco/sqlite-data")
        ),
        ThirdPartyLibrary(
            name: "Lottie",
            license: "Apache-2.0",
            url: URL(string: "https://github.com/airbnb/lottie-ios")
        ),
        ThirdPartyLibrary(
            name: "KeychainAccess",
            license: "MIT",
            url: URL(string: "https://github.com/kishikawakatsumi/KeychainAccess")
        )
    ]
}
