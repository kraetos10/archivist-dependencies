#if os(tvOS)
import SwiftUI
import UIKit

public struct TVVLCPlayerView: View {
    @Environment(\.dismiss) private var dismiss

    private let playerManager = PlayerManager.shared

    @State private var model = TVPlayerControlsModel()
    @AppStorage(ChildMode.enabledKey) private var childModeEnabled = false

    private static let barHeight: CGFloat = 10
    private static let thinBarHeight: CGFloat = 6
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

            // Child mode gets no card to pick from, as on iOS; the
            // countdown still advances on its own.
            if !childModeEnabled, let countdown = playerManager.autoPlayCountdown {
                // The video has ended, so the card replaces the controls,
                // and the press capture below steps aside so focus can
                // reach its buttons. Menu closes the player, which the
                // reducer takes as Cancel.
                TVAutoPlayCountdownOverlay(
                    info: countdown,
                    onPlayNow: { playerManager.emit(.autoPlayPlayNowTapped) },
                    onCancel: { playerManager.emit(.autoPlayCancelTapped) }
                )
                .transition(.opacity)
            } else {
                playbackChrome
            }

            SponsorSkipBanner()
        }
        .animation(.easeInOut(duration: 0.3), value: playerManager.autoPlayCountdown == nil)
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
        .onChange(of: playerManager.upNextItems) { model.upNextItemsChanged() }
        .onDisappear { model.teardown() }
    }

    /// Buffering spinner, controls and remote capture while a video plays.
    @ViewBuilder
    private var playbackChrome: some View {
        if playerManager.isBuffering {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        }

        if model.controlsVisible {
            controlsOverlay
                .transition(.opacity)
        }

        skipFeedbackView

        upNextHint
            .animation(.easeInOut(duration: 0.3), value: model.upNextHint)

        // Press-event capture: `.onMoveCommand` only fires once per
        // press cycle so it can't distinguish a quick tap from a
        // hold. Routing the arrows through UIPress lets us treat a
        // sub-300ms left/right press as a discrete skip and a longer
        // hold as rewind / fast-forward. The same view carries the
        // touch-surface pan used for scrubbing. It steps aside while the
        // Up Next ribbon is browsed or the hint card is focused, so focus
        // can reach them.
        if !model.isBrowsingUpNext, !model.isFocusingHint {
            pressCapture
        }
    }

    private var pressCapture: some View {
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

    /// Apple TV app layout: no panels, just dark gradients at the top and
    /// bottom edges, the title large at top-left and the transport along
    /// the bottom.
    private var controlsOverlay: some View {
        ZStack {
            edgeGradients

            VStack(alignment: .leading, spacing: 0) {
                titleBlock
                Spacer()
                transportBlock
                if model.showsUpNextRibbon {
                    TVUpNextRibbon(
                        items: model.upNextItems,
                        isBrowsing: model.isBrowsingUpNext,
                        onSelect: { item in model.selectUpNext(item) },
                        onExit: { model.exitUpNext() }
                    )
                    .onPlayPauseCommand { playerManager.togglePlayPause() }
                    .padding(.top, 20)
                }
            }
            .padding(.horizontal, 80)
            .padding(.vertical, 60)
        }
    }

    private var edgeGradients: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.75), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 360)
            Spacer()
            LinearGradient(
                colors: [.clear, .black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: model.isBrowsingUpNext ? 760 : 420)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var titleBlock: some View {
        if let metadata = playerManager.currentMetadata {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 14) {
                    if let thumb = metadata.channelThumbURL {
                        AsyncImage(url: thumb) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            default:
                                Circle().fill(.white.opacity(0.2))
                            }
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(Circle())
                        // Decorative: the channel name beside it says who it is.
                        .accessibilityHidden(true)
                    }
                    Text(metadata.artist)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
                Text(metadata.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .frame(maxWidth: 1200, alignment: .leading)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .accessibilityElement(children: .combine)
        }
    }

    private var transportBlock: some View {
        VStack(spacing: 18) {
            progressBar

            HStack(spacing: 16) {
                Image(systemName: model.statusIconName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(minWidth: 40)
                    .accessibilityLabel(model.statusAccessibilityLabel)

                Text(playerManager.currentTimeDisplay)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                speedHint

                Text(model.remainingTimeDisplay)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    /// Up on the remote opens the speed picker; this says so.
    private var speedHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.up")
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
    /// barely-visible track on a dark background. Thin while playing; it
    /// thickens and grows a knob while scrubbing, seeking or paused, with
    /// the target time floating above the knob while scrubbing.
    private var progressBar: some View {
        let showsKnob = model.showsKnob
        let barHeight = showsKnob ? Self.barHeight : Self.thinBarHeight
        return GeometryReader { geometry in
            let width = geometry.size.width
            let knobX = width * model.knobProgress
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: barHeight)
                Capsule()
                    .fill(Color.white)
                    .frame(width: width * model.playbackProgress, height: barHeight)
                if showsKnob {
                    Circle()
                        .fill(Color.white)
                        .frame(width: Self.knobSize, height: Self.knobSize)
                        .shadow(color: .black.opacity(0.4), radius: 4)
                        .offset(x: knobX - Self.knobSize / 2)
                        .transition(.scale.combined(with: .opacity))
                }
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
        .animation(.easeOut(duration: 0.2), value: showsKnob)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String.localised("video.watchProgress", table: .videos))
        .accessibilityValue(model.progressAccessibilityValue)
    }

    /// A ten-second skip, flashed beside the video on the side it went.
    @ViewBuilder
    private var skipFeedbackView: some View {
        if let feedback = model.skipFeedback {
            let isForward = feedback.direction == .forward
            Image(systemName: isForward ? "goforward.10" : "gobackward.10")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 160, height: 160)
                .background(.ultraThinMaterial, in: Circle())
                .id(feedback.id)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .frame(maxWidth: .infinity, alignment: isForward ? .trailing : .leading)
                .padding(.horizontal, 160)
                .accessibilityHidden(true)
        }
    }

    /// The next video, as a card with its thumbnail, in the last stretch of
    /// the video so the countdown that follows isn't a surprise. Sits above
    /// the transport, shown whether or not the controls are. Down focuses
    /// it and Select plays it now.
    @ViewBuilder
    private var upNextHint: some View {
        if let item = model.upNextHint {
            TVUpNextHintCard(
                item: item,
                isFocusing: model.isFocusingHint,
                onSelect: { model.selectHint(item) },
                onExit: { model.exitHint() }
            )
            .onPlayPauseCommand { playerManager.togglePlayPause() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.horizontal, 80)
            .padding(.bottom, 180)
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .onDisappear { model.exitHint() }
        }
    }
}
#endif
