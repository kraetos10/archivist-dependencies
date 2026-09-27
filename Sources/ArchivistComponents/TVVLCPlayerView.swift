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
#endif
