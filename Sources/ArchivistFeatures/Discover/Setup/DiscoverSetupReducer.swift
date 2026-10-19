#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

/// The first-run walkthrough for getting a YouTube Data API key: what Discover
/// needs and why, the Google Cloud steps in order, and a paste-and-verify
/// step that only saves a key YouTube has accepted.
@Reducer
public struct DiscoverSetupReducer {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
        public enum Step: Int, CaseIterable, Sendable {
            case intro
            case project
            case enableAPI
            case createKey
            case paste
        }

        public enum Failure: Equatable, Sendable {
            case invalidKey
            case apiNotEnabled
            case network
            case unexpected
        }

        public var step: Step = .intro
        public var keyInput = ""
        public var isVerifying = false
        public var failure: Failure?
        /// The saved key stopped working, so the flow opens on the key step
        /// with a note saying why, rather than repeating the explanation.
        public var wasKeyRejected = false

        public init(wasKeyRejected: Bool = false) {
            self.wasKeyRejected = wasKeyRejected
            if wasKeyRejected {
                step = .paste
            }
        }

        var trimmedKey: String {
            keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var canVerify: Bool {
            !trimmedKey.isEmpty && !isVerifying
        }

        var isFirstStep: Bool { step == .intro }
        var isLastStep: Bool { step == .paste }
        var stepNumber: Int { step.rawValue + 1 }
        var stepCount: Int { Step.allCases.count }
    }

    /// Where each Google Cloud step happens.
    public enum Link: Sendable, Equatable {
        case createProject
        case enableAPI
        case credentials

        var url: URL? {
            switch self {
            case .createProject:
                URL(string: "https://console.cloud.google.com/projectcreate")
            case .enableAPI:
                URL(string: "https://console.cloud.google.com/apis/library/youtube.googleapis.com")
            case .credentials:
                URL(string: "https://console.cloud.google.com/apis/credentials")
            }
        }
    }

    public enum Action: ViewAction, BindableAction {
        case binding(BindingAction<State>)
        case view(View)
        case verifyResult(Result<Void, Error>)
        case delegate(Delegate)

        @CasePathable
        public enum View {
            case nextTapped
            case backTapped
            case openLinkTapped(Link)
            case pasted(String)
            case verifyTapped
            case closeTapped
        }

        @CasePathable
        public enum Delegate: Equatable {
            case keySaved(String)
            case cancelled
        }
    }

    @Dependency(\.youTubeSearchService) var youTubeSearchService
    @Dependency(\.youTubeAPIKeyStore) var youTubeAPIKeyStore
    @Dependency(\.openURL) var openURL

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding(\.keyInput):
                state.failure = nil
                return .none
            case .binding, .delegate:
                return .none
            case .view(let viewAction):
                return handleViewAction(viewAction, state: &state)
            case .verifyResult(let result):
                return handleVerifyResult(result, state: &state)
            }
        }
    }
}
#endif
