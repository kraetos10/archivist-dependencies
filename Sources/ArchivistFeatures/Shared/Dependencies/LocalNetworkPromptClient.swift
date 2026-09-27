import ArchivistComponents
import ComposableArchitecture

/// Triggers the system local-network privacy prompt, so the first request
/// to a LAN server isn't the thing that silently fails while it's up.
@DependencyClient
public struct LocalNetworkPromptClient: Sendable {
    public var trigger: @Sendable () -> Void
}

extension LocalNetworkPromptClient: DependencyKey {
    public static var liveValue: LocalNetworkPromptClient {
        LocalNetworkPromptClient(trigger: { LocalNetworkPrompt.triggerLocalNetworkPrivacyAlert() })
    }

    public static var testValue: LocalNetworkPromptClient { LocalNetworkPromptClient() }

    public static var previewValue: LocalNetworkPromptClient {
        LocalNetworkPromptClient(trigger: {})
    }
}

extension DependencyValues {
    public var localNetworkPrompt: LocalNetworkPromptClient {
        get { self[LocalNetworkPromptClient.self] }
        set { self[LocalNetworkPromptClient.self] = newValue }
    }
}
