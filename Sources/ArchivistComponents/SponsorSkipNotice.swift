#if !os(watchOS)
import Observation

/// The "Skipped by SponsorBlock" banner's state: visible for a few seconds
/// after each skip. Lives outside any reducer because the fullscreen and
/// tvOS players that draw it can't see the video detail store.
@MainActor
@Observable
public final class SponsorSkipNotice {
    public static let shared = SponsorSkipNotice()

    public private(set) var isVisible = false

    @ObservationIgnored private let displayDuration: Duration
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    public init(displayDuration: Duration = .seconds(4)) {
        self.displayDuration = displayDuration
    }

    /// Shows the banner, restarting its countdown if it is already up.
    public func skipped() {
        isVisible = true
        hideTask?.cancel()
        hideTask = Task { [displayDuration] in
            try? await Task.sleep(for: displayDuration)
            guard !Task.isCancelled else { return }
            isVisible = false
        }
    }

    /// Hides it at once, as a new video starts.
    public func clear() {
        hideTask?.cancel()
        hideTask = nil
        isVisible = false
    }
}
#endif
