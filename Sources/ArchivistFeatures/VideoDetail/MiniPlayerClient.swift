import ArchivistNetworking
import ComposableArchitecture

/// What a `VideoDetail` screen wants the mini player to do.
public enum MiniPlayerRequest: Sendable {
    /// The user dragged this screen down. Carries the state to carry over
    /// so the tab doesn't have to go hunting through child state for it.
    case minimise(VideoDetailReducer.State)

    /// A video detail screen came on screen, so any mini player has to get
    /// out of the way — two surfaces can't both host the player. Carries
    /// the appearing screen's video so the tab can tell the two cases
    /// apart: a *different* video means stop and save a resume position, the
    /// *same* video means hand the running playback back to the screen.
    case detailAppeared(videoId: String)
}

/// Carries mini-player requests from whichever `VideoDetail` screen raised
/// them up to `TabReducer` — which owns the mini player because it has to
/// outlive the navigation stack the detail was pushed onto.
///
/// A delegate chain would have to be threaded through every reducer that
/// can present a video detail — the video list and its navigation path,
/// channels, channel detail, playlists, settings, device downloads — and
/// re-threaded for every route added later. The requests are all
/// route-independent, so they travel out of band instead. This is the same
/// shape as the `PiPMinimizeService` the project used before the mini
/// player was removed.
public struct MiniPlayerClient: Sendable {
    /// Publish a request.
    public var request: @Sendable (MiniPlayerRequest) async -> Void
    /// Clear the pending request once the tab has acted on it, so a later
    /// subscriber doesn't replay a stale one.
    public var consume: @Sendable () async -> Void
    /// Stream of pending requests. Emits the current value on subscribe,
    /// so subscribers must skip `nil`.
    public var subscribe: @Sendable () async -> AsyncStream<MiniPlayerRequest?>

    public init(
        request: @escaping @Sendable (MiniPlayerRequest) async -> Void,
        consume: @escaping @Sendable () async -> Void,
        subscribe: @escaping @Sendable () async -> AsyncStream<MiniPlayerRequest?>
    ) {
        self.request = request
        self.consume = consume
        self.subscribe = subscribe
    }
}

extension MiniPlayerClient: DependencyKey {
    private static let sharedStore = ValueStore<MiniPlayerRequest?>(nil)

    public static var liveValue: Self {
        makeClient(store: sharedStore)
    }

    public static var testValue: Self {
        makeClient(store: ValueStore<MiniPlayerRequest?>(nil))
    }

    private static func makeClient(
        store: ValueStore<MiniPlayerRequest?>
    ) -> Self {
        MiniPlayerClient { request in
            await store.set(to: request)
        } consume: {
            await store.set(to: nil)
        } subscribe: {
            await store.stream()
        }
    }
}

public extension DependencyValues {
    var miniPlayerClient: MiniPlayerClient {
        get { self[MiniPlayerClient.self] }
        set { self[MiniPlayerClient.self] = newValue }
    }
}
