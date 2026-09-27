#if os(tvOS)
import SwiftUI
import UIKit

/// State and remote handling for the tvOS player chrome. Kept out of the
/// view so the view only renders what this has already worked out.
@MainActor
@Observable
final class TVPlayerControlsModel {
    enum TapResult {
        case handled
        case dismiss
    }

    enum SeekMode {
        case rewind
        case fastForward
    }

    /// How much of the video one full-width swipe across the touch surface
    /// covers. Needs tuning on a real Siri Remote.
    private static let scrubSpan: Double = 1.0
    /// A scrub that moves less than this is a stray touch, not a seek.
    private static let minimumScrubDistance: Double = 1
    /// Keep seeks clear of the very end — libvlc reports a seek onto the
    /// end as `.stopped`, which reads as a failed/ended video.
    private static let endGuard: Double = 2
    /// Interval between backward jumps while Left is held.
    private static let rewindTick: Duration = .milliseconds(500)

    private let playerManager: PlayerManager

    private(set) var controlsVisible = true
    private(set) var seekMode: SeekMode?
    /// Where the knob sits while scrubbing or rewinding; nil otherwise.
    private(set) var scrubTime: Double?
    private(set) var isScrubbing = false

    /// The speed picker is open. The controls stay up meanwhile, and the
    /// auto-hide restarts once it closes.
    var isSpeedPickerPresented = false {
        didSet {
            guard isSpeedPickerPresented != oldValue else { return }
            if isSpeedPickerPresented {
                hideTask?.cancel()
            } else {
                scheduleHide()
            }
        }
    }

    @ObservationIgnored private var hideTask: Task<Void, Never>?
    @ObservationIgnored private var rewindTask: Task<Void, Never>?
    @ObservationIgnored private var scrubOrigin: Double = 0

    init(playerManager: PlayerManager = .shared) {
        self.playerManager = playerManager
    }

    // MARK: Display

    var playbackProgress: Double {
        fraction(of: playerManager.currentTime)
    }

    var knobProgress: Double {
        fraction(of: scrubTime ?? playerManager.currentTime)
    }

    var scrubTimeDisplay: String? {
        scrubTime.map(Self.formatTime)
    }

    var statusIconName: String {
        switch seekMode {
        case .rewind: return "backward.fill"
        case .fastForward: return "forward.fill"
        case nil: return playerManager.isPlaying ? "play.fill" : "pause.fill"
        }
    }

    var statusAccessibilityLabel: String {
        switch seekMode {
        case .rewind:
            return String.localised("video.state.rewinding", table: .videos)
        case .fastForward:
            return String.localised("video.state.fastForwarding", table: .videos)
        case nil:
            return playerManager.isPlaying
                ? String.localised("video.state.playing", table: .videos)
                : String.localised("video.state.paused", table: .videos)
        }
    }

    var progressAccessibilityValue: String {
        String.localised(
            "video.progressValue \(playerManager.currentTimeDisplay) \(playerManager.durationDisplay)",
            table: .videos
        )
    }

    // MARK: Remote input

    /// Every press but a held Left/Right lands here, on release, however
    /// long it was held.
    func handleTap(_ type: UIPress.PressType) -> TapResult {
        switch type {
        case .leftArrow:
            playerManager.skipBackward(10)
            poke()
        case .rightArrow:
            playerManager.skipForward(10)
            poke()
        case .downArrow:
            showControls()
            isSpeedPickerPresented = true
        case .select where hasScrubbedAway:
            // A click after a real swipe commits the scrub rather than pausing.
            commitScrub()
            poke()
        case .playPause, .select:
            // A resting thumb can start a scrub without moving it anywhere;
            // that's still a pause, not a seek.
            if isScrubbing {
                endScrub()
            }
            playerManager.togglePlayPause()
            poke()
        case .menu:
            return handleMenu()
        default:
            poke()
        }
        return .handled
    }

    /// Menu backs out one layer at a time: a scrub in progress, then the
    /// controls, then the player itself.
    private func handleMenu() -> TapResult {
        if isScrubbing {
            endScrub()
            poke()
            return .handled
        }
        if controlsVisible {
            hideControls()
            return .handled
        }
        return .dismiss
    }

    func handleHoldBegan(_ type: UIPress.PressType) {
        switch type {
        case .rightArrow:
            seekMode = .fastForward
            playerManager.setPlaybackRate(4.0)
            showControls()
        case .leftArrow:
            startRewind()
        default:
            break
        }
    }

    func handleHoldEnded(_ type: UIPress.PressType) {
        switch type {
        case .rightArrow:
            playerManager.restorePlaybackSpeed()
            seekMode = nil
            poke()
        case .leftArrow:
            stopRewind()
            poke()
        default:
            break
        }
    }

    // MARK: Scrubbing

    func scrubBegan() {
        // A swipe while the controls are hidden just brings them back;
        // scrubbing something you can't see would be a surprise.
        guard controlsVisible, seekMode == nil, playerManager.effectiveDuration > 0 else {
            poke()
            return
        }
        isScrubbing = true
        scrubOrigin = playerManager.currentTime
        scrubTime = scrubOrigin
        hideTask?.cancel()
    }

    func scrubChanged(fraction: CGFloat) {
        guard isScrubbing else { return }
        let total = playerManager.effectiveDuration
        guard total > 0 else { return }
        let target = scrubOrigin + Double(fraction) * total * Self.scrubSpan
        scrubTime = min(max(target, 0), max(total - Self.endGuard, 0))
    }

    func scrubEnded(cancelled: Bool) {
        guard isScrubbing else { return }
        if cancelled {
            endScrub()
        } else {
            commitScrub()
        }
        scheduleHide()
    }

    /// A scrub is in progress and has moved far enough to count as a seek.
    private var hasScrubbedAway: Bool {
        guard isScrubbing, let target = scrubTime else { return false }
        return abs(target - scrubOrigin) >= Self.minimumScrubDistance
    }

    private func commitScrub() {
        if hasScrubbedAway, let target = scrubTime {
            playerManager.seekTo(target)
        }
        endScrub()
    }

    private func endScrub() {
        isScrubbing = false
        scrubTime = nil
    }

    // MARK: Rewind

    /// libvlc can't play backwards, so a held Left is a run of backward
    /// jumps that grow the longer it's held. The target is tracked here
    /// rather than re-read from `currentTime`, which lags each seek.
    private func startRewind() {
        seekMode = .rewind
        showControls()
        let start = playerManager.currentTime
        scrubTime = start
        rewindTask?.cancel()
        rewindTask = Task { [weak self] in
            var target = start
            var ticks = 0
            while !Task.isCancelled {
                guard let self else { return }
                let step = Self.rewindStep(afterTicks: ticks)
                target = max(target - step, 0)
                self.scrubTime = target
                self.playerManager.seekTo(target)
                ticks += 1
                if target <= 0 { return }
                try? await Task.sleep(for: Self.rewindTick)
            }
        }
    }

    private func stopRewind() {
        rewindTask?.cancel()
        rewindTask = nil
        seekMode = nil
        scrubTime = nil
    }

    /// 10s jumps for the first two seconds held, then 20s, then 40s, capped at 60s.
    private static func rewindStep(afterTicks ticks: Int) -> Double {
        switch ticks {
        case ..<4: return 10
        case ..<8: return 20
        case ..<12: return 40
        default: return 60
        }
    }

    // MARK: Speed

    func selectSpeed(_ speed: Float) {
        playerManager.setPlaybackSpeed(speed)
    }

    // MARK: Visibility

    /// Show the controls and restart the auto-hide timer. Called on appear
    /// and after any input.
    func poke() {
        showControls()
        scheduleHide()
    }

    /// Playback paused, resumed, or started/stopped buffering. A pause
    /// brings the controls up; either way the auto-hide is re-evaluated.
    func playbackStateChanged() {
        if !playerManager.isPlaying && !playerManager.isBuffering {
            showControls()
        }
        guard controlsVisible else { return }
        scheduleHide()
    }

    func teardown() {
        hideTask?.cancel()
        rewindTask?.cancel()
        // Restore the rate in case the view is dismissed mid-hold,
        // otherwise the next playback session inherits 4× speed.
        playerManager.restorePlaybackSpeed()
    }

    /// Nothing hides the controls while there's something to look at: a
    /// paused or buffering video, a scrub or hold in progress, the picker.
    private var holdsControls: Bool {
        !playerManager.isPlaying
            || playerManager.isBuffering
            || isScrubbing
            || seekMode != nil
            || isSpeedPickerPresented
    }

    private func scheduleHide() {
        hideTask?.cancel()
        guard !holdsControls else { return }
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard let self, !Task.isCancelled, !self.holdsControls else { return }
            self.hideControls()
        }
    }

    private func showControls() {
        guard !controlsVisible else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
    }

    private func hideControls() {
        hideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = false
        }
    }

    private func fraction(of time: Double) -> Double {
        let total = playerManager.effectiveDuration
        guard total > 0, time.isFinite else { return 0 }
        return min(max(time / total, 0), 1)
    }

    private static func formatTime(_ seconds: Double) -> String {
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= 3600 ? .hourMinuteSecond : .minuteSecond
        return Duration.seconds(max(seconds, 0)).formatted(.time(pattern: pattern))
    }
}
#endif
