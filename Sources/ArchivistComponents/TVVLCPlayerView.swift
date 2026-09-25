#if os(tvOS)
import SwiftUI
import UIKit

public struct TVVLCPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let playerManager = PlayerManager.shared

    @State private var model = TVPlayerControlsModel()

    private static let barHeight: CGFloat = 10
    private static let knobSize: CGFloat = 24

    public init() {}

    public var body: some View {
        ZStack {
            TVVLCVideoRenderView()
                .ignoresSafeArea()
                // Stop the embedded VLC host UIView from intercepting
                // tvOS focus / remote events — without this the press
                // events captured below never reach our handler.
                .allowsHitTesting(false)

            if playerManager.isBuffering {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }

            if model.controlsVisible {
                controlsOverlay
                    .transition(.opacity)
            }

            // Press-event capture: `.onMoveCommand` only fires once per
            // press cycle so it can't distinguish a quick tap from a
            // hold. Routing the arrows through UIPress lets us treat a
            // sub-300ms left/right press as a discrete skip and a longer
            // hold as rewind / fast-forward. The same view carries the
            // touch-surface pan used for scrubbing.
            TVPlayerPressView(
                onTap: { type in
                    if model.handleTap(type) == .dismiss {
                        dismiss()
                    }
                },
                onHoldBegan: { type in model.handleHoldBegan(type) },
                onHoldEnded: { type in model.handleHoldEnded(type) },
                onScrubBegan: { model.scrubBegan() },
                onScrubChanged: { fraction in model.scrubChanged(fraction: fraction) },
                onScrubEnded: { cancelled in model.scrubEnded(cancelled: cancelled) }
            )
        }
        .confirmationDialog(
            String.localised("video.playbackSpeed", table: .videos),
            isPresented: $model.isSpeedPickerPresented,
            titleVisibility: .visible
        ) {
            ForEach(PlaybackSpeed.options, id: \.self) { speed in
                Button(PlaybackSpeed.label(for: speed)) {
                    model.selectSpeed(speed)
                }
            }
        }
        .onAppear { model.poke() }
        .onChange(of: playerManager.isPlaying) { model.playbackStateChanged() }
        .onChange(of: playerManager.isBuffering) { model.playbackStateChanged() }
        .onDisappear { model.teardown() }
    }

    @ViewBuilder
    private var controlsOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let metadata = playerManager.currentMetadata {
                HStack(spacing: 12) {
                    if let thumb = metadata.channelThumbURL {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Circle().fill(.white.opacity(0.2))
                            }
                        }
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        // Decorative: the channel name beside it says who it is.
                        .accessibilityHidden(true)
                    }
                    Text(metadata.artist)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("·")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                        .accessibilityHidden(true)
                    Text(metadata.title)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Spacer()

            VStack(spacing: 16) {
                progressBar

                HStack(spacing: 16) {
                    Image(systemName: model.statusIconName)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(minWidth: 40)
                        .accessibilityLabel(model.statusAccessibilityLabel)

                    Text(playerManager.currentTimeDisplay)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    speedHint

                    Text(playerManager.durationDisplay)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 80)
        .padding(.vertical, 60)
    }

    /// Down on the remote opens the speed picker; this says so.
    private var speedHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.down")
                .accessibilityHidden(true)
            Text(String.localised("video.speed", table: .videos))
            Text(playerManager.playbackSpeedLabel)
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .font(.callout)
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.white.opacity(0.15), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String.localised("video.playbackSpeed", table: .videos))
        .accessibilityValue(playerManager.playbackSpeedLabel)
    }

    /// Custom progress bar — the SwiftUI default `ProgressView` has a
    /// barely-visible track on a dark background. The knob tracks the
    /// playhead, or the scrub target while scrubbing, with the target time
    /// floating above it.
    private var progressBar: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let knobX = width * model.knobProgress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: Self.barHeight)
                Capsule()
                    .fill(Color.white)
                    .frame(width: width * model.playbackProgress, height: Self.barHeight)
                Circle()
                    .fill(Color.white)
                    .frame(width: Self.knobSize, height: Self.knobSize)
                    .shadow(color: .black.opacity(0.4), radius: 4)
                    .offset(x: knobX - Self.knobSize / 2)
                if let scrubLabel = model.scrubTimeDisplay {
                    Text(scrubLabel)
                        .font(.callout.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.85), in: Capsule())
                        .fixedSize()
                        .position(x: min(max(knobX, 60), max(width - 60, 60)), y: -36)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: Self.knobSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String.localised("video.watchProgress", table: .videos))
        .accessibilityValue(model.progressAccessibilityValue)
    }
}

// MARK: - Controls model

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

// MARK: - Press and touch capture

/// Captures raw UIPress events from the Siri Remote. Left/Right go through
/// hold detection: a quick press dispatches `onTap`, one still down after
/// `holdThreshold` dispatches `onHoldBegan` and a matching `onHoldEnded` on
/// release. Every other press dispatches `onTap` on release, however long
/// it was held. A pan on the touch surface drives the `onScrub*` callbacks.
private struct TVPlayerPressView: UIViewRepresentable {
    let onTap: (UIPress.PressType) -> Void
    let onHoldBegan: (UIPress.PressType) -> Void
    let onHoldEnded: (UIPress.PressType) -> Void
    let onScrubBegan: () -> Void
    let onScrubChanged: (CGFloat) -> Void
    let onScrubEnded: (Bool) -> Void

    func makeUIView(context: Context) -> TVPressTrackingView {
        let view = TVPressTrackingView()
        apply(to: view)
        return view
    }

    func updateUIView(_ uiView: TVPressTrackingView, context: Context) {
        apply(to: uiView)
    }

    private func apply(to view: TVPressTrackingView) {
        view.onTap = onTap
        view.onHoldBegan = onHoldBegan
        view.onHoldEnded = onHoldEnded
        view.onScrubBegan = onScrubBegan
        view.onScrubChanged = onScrubChanged
        view.onScrubEnded = onScrubEnded
    }
}

private final class TVPressTrackingView: UIView {
    var onTap: ((UIPress.PressType) -> Void)?
    var onHoldBegan: ((UIPress.PressType) -> Void)?
    var onHoldEnded: ((UIPress.PressType) -> Void)?
    var onScrubBegan: (() -> Void)?
    /// Horizontal translation as a fraction of this view's width.
    var onScrubChanged: ((CGFloat) -> Void)?
    /// `true` when the pan was cancelled rather than finished.
    var onScrubEnded: ((Bool) -> Void)?

    /// Threshold above which a Left/Right press is treated as a hold
    /// rather than a discrete tap.
    private let holdThreshold: Duration = .milliseconds(300)

    /// Presses whose length matters — held, they rewind / fast-forward.
    private static let holdTypes: Set<UIPress.PressType> = [.leftArrow, .rightArrow]
    /// Presses that are always a tap, dispatched on release.
    private static let tapTypes: Set<UIPress.PressType> = [
        .upArrow, .downArrow, .playPause, .select, .menu
    ]

    private var holdTimers: [UIPress.PressType: Task<Void, Never>] = [:]
    private var heldPresses: Set<UIPress.PressType> = []
    /// Presses that began on this view. A release only counts if its press
    /// did — Menu dismissing the speed picker must not also reach here as a
    /// fresh Menu and close the player.
    private var activePresses: Set<UIPress.PressType> = []

    override var canBecomeFocused: Bool { true }

    override init(frame: CGRect) {
        super.init(frame: frame)
        installScrubGesture()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installScrubGesture()
    }

    private func installScrubGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        pan.cancelsTouchesInView = false
        addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            onScrubBegan?()
        case .changed:
            let width = max(bounds.width, 1)
            onScrubChanged?(recognizer.translation(in: self).x / width)
        case .ended:
            onScrubEnded?(false)
        case .cancelled, .failed:
            onScrubEnded?(true)
        default:
            break
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            if Self.holdTypes.contains(press.type) {
                activePresses.insert(press.type)
                schedule(press.type)
            } else if Self.tapTypes.contains(press.type) {
                activePresses.insert(press.type)
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesBegan(unhandled, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            let type = press.type
            if Self.holdTypes.contains(type) {
                if activePresses.remove(type) != nil {
                    resolve(type)
                }
            } else if Self.tapTypes.contains(type) {
                if activePresses.remove(type) != nil {
                    onTap?(type)
                }
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesEnded(unhandled, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var unhandled = Set<UIPress>()
        for press in presses {
            let type = press.type
            if Self.holdTypes.contains(type) || Self.tapTypes.contains(type) {
                activePresses.remove(type)
                cancel(type)
            } else {
                unhandled.insert(press)
            }
        }
        if !unhandled.isEmpty {
            super.pressesCancelled(unhandled, with: event)
        }
    }

    private func schedule(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = Task { @MainActor [weak self, holdThreshold] in
            try? await Task.sleep(for: holdThreshold)
            guard let self, !Task.isCancelled else { return }
            self.heldPresses.insert(type)
            self.onHoldBegan?(type)
        }
    }

    private func resolve(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = nil
        if heldPresses.remove(type) != nil {
            onHoldEnded?(type)
        } else {
            onTap?(type)
        }
    }

    private func cancel(_ type: UIPress.PressType) {
        holdTimers[type]?.cancel()
        holdTimers[type] = nil
        if heldPresses.remove(type) != nil {
            onHoldEnded?(type)
        }
    }
}

private final class TVVLCPlayerHostView: UIView {
    func adoptPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView else { return }
        if playerView.superview === self { return }

        playerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(playerView)
        NSLayoutConstraint.activate([
            playerView.topAnchor.constraint(equalTo: topAnchor),
            playerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            playerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            playerView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func detachPlayerView() {
        guard let playerView = PlayerManager.shared.persistentVLCPlayerView,
              playerView.superview === self else { return }
        playerView.removeFromSuperview()
    }
}

private struct TVVLCVideoRenderView: UIViewRepresentable {
    func makeUIView(context: Context) -> TVVLCPlayerHostView {
        let view = TVVLCPlayerHostView()
        view.backgroundColor = .black
        return view
    }

    func updateUIView(_ uiView: TVVLCPlayerHostView, context: Context) {
        uiView.adoptPlayerView()
    }

    static func dismantleUIView(_ uiView: TVVLCPlayerHostView, coordinator: ()) {
        uiView.detachPlayerView()
    }
}
#endif
