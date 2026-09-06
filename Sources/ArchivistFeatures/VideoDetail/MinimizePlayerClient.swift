import ArchivistNetworking
import ComposableArchitecture

/// Carries a "minimise me, here is my state" request from whichever
/// `VideoDetail` screen the user dragged down, up to `TabReducer` — which
/// owns the mini player because the mini player has to outlive the
/// navigation stack the detail was pushed onto.
///
/// A delegate chain would have to be threaded through every reducer that
/// can present a video detail — the video list and its navigation path,
/// channels, channel detail, playlists, settings, device downloads — and
/// re-threaded for every route added later. The request itself is
/// route-independent, so it travels out of band instead. This is the same
/// shape as the `PiPMinimizeService` the project used before the mini
/// player was removed, with the detail state added to the payload so the
/// tab doesn't have to go hunting through child state for it.
public struct MinimizePlayerClient: Sendable {
    /// Publish a minimise request carrying the detail state to hand over.
    public var request: @Sendable (VideoDetailReducer.State) async -> Void
    /// Clear the pending request once the tab has taken ownership, so a
    /// later subscriber doesn't replay a stale one.
    public var consume: @Sendable () async -> Void
    /// Stream of pending requests. Emits the current value on subscribe,
    /// so subscribers must skip `nil`.
    public var subscribe: @Sendable () async -> AsyncStream<VideoDetailReducer.State?>

    public init(
        request: @escaping @Sendable (VideoDetailReducer.State) async -> Void,
        consume: @escaping @Sendable () async -> Void,
        subscribe: @escaping @Sendable () async -> AsyncStream<VideoDetailReducer.State?>
    ) {
        self.request = request
        self.consume = consume
        self.subscribe = subscribe
    }
}

extension MinimizePlayerClient: DependencyKey {
    private static let sharedStore = ValueStore<VideoDetailReducer.State?>(nil)

    public static var liveValue: Self {
        makeClient(store: sharedStore)
    }

    public static var testValue: Self {
        makeClient(store: ValueStore<VideoDetailReducer.State?>(nil))
    }

    private static func makeClient(
        store: ValueStore<VideoDetailReducer.State?>
    ) -> Self {
        MinimizePlayerClient { detail in
            await store.set(to: detail)
        } consume: {
            await store.set(to: nil)
        } subscribe: {
            await store.stream()
        }
    }
}

public extension DependencyValues {
    var minimizePlayer: MinimizePlayerClient {
        get { self[MinimizePlayerClient.self] }
        set { self[MinimizePlayerClient.self] = newValue }
    }
}
