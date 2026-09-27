#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct ChildVideoPlayerScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>
    /// Read-only, for rendering the live transport (play state, position).
    /// Every control goes through the reducer.
    private let playerManager = PlayerManager.shared
    @State private var overlayShown: Bool = true

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            playerLayer

            // Tap-toggled kid chrome: close button at top, transport
            // (play/pause + thick seek bar + time) sitting directly above
            // the similar-videos rail at the bottom. No auto-hide — only
            // the user's tap on the player flips visibility — keeps the
            // mental model simple for kids.
            VStack(alignment: .leading, spacing: 12) {
                topBar
                Spacer()
                transportBar
                if !store.similarVideos.isEmpty {
                    similarVideosOverlay
                }
            }
            .padding(.bottom, 8)
            .opacity(overlayShown ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: overlayShown)
            .allowsHitTesting(overlayShown)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .bottomBar)
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            send(.viewDidAppear)
        }
        .onChange(of: store.video.videoId) {
            overlayShown = true
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    @ViewBuilder
    private var playerLayer: some View {
        if store.isPlaying {
            VLCPlayerView()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: toggleOverlay)
                // The tap is the only way back to the hidden chrome, and a
                // bare tap gesture is invisible to VoiceOver.
                .accessibilityElement()
                .accessibilityLabel(String.localised("video.player", table: .videos))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction(
                    named: String.localised("video.toggleControls", table: .videos),
                    toggleOverlay
                )
        } else {
            thumbnailLayer
        }
    }

    private func toggleOverlay() {
        overlayShown.toggle()
    }

    private var thumbnailLayer: some View {
        ZStack {
            Color.black

            if let url = store.thumbnailURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    default:
                        Color.black
                    }
                }
            }

            Image(systemName: "play.circle.fill")
                .scaledSystemFont(size: 72, relativeTo: .largeTitle)
                .foregroundStyle(.white.opacity(0.95))
                .shadow(radius: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture { send(.playTapped) }
        // A bare `onTapGesture` carries no accessibility traits, so
        // VoiceOver saw the thumbnail as static art with no way to start
        // playback. Collapse the stack into one button element instead.
        .accessibilityElement()
        .accessibilityLabel(String.localised("video.playVideo", table: .videos))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { send(.playTapped) }
    }

    private var topBar: some View {
        HStack {
            Button { send(.dismissTapped) } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .accessibilityLabel(String.localised("generic.close", table: .generic))
            Spacer()
        }
        // Outer ZStack respects safe area, so this sits below the
        // dynamic island / status bar automatically — only a small
        // visual offset is needed.
        .padding(.top, 8)
        .padding(.leading, 16)
        .padding(.trailing, 16)
    }

    private var similarVideosOverlay: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(store.similarVideos) { video in
                    Button {
                        send(.similarVideoTapped(video))
                    } label: {
                        // SimilarVideoCard hardcodes its own 200pt width;
                        // wrapping it in another `.frame(width:)` was
                        // making the HStack reserve a smaller slot than
                        // the card actually rendered into, so adjacent
                        // cards visually collided.
                        SimilarVideoCard(
                            video: video,
                            serverConfig: store.serverConfig,
                            showsStats: false
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
    }

    private var transportBar: some View {
        HStack(spacing: 16) {
            // Transport chrome over video: fixed size on purpose.
            Button {
                send(.childPlayPauseTapped)
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                playerManager.isPlaying
                    ? String.localised("video.pause", table: .videos)
                    : String.localised("video.play", table: .videos)
            )

            ChildSeekBar(
                progress: playerManager.playbackFraction,
                valueDescription: playerManager.currentTimeDisplay,
                onSeek: { send(.childSeekRequested($0)) }
            )

            Text("\(playerManager.currentTimeDisplay) / \(playerManager.durationDisplay)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 12)
    }
}

extension PlayerManager {
    /// How far through the video playback is, from 0 to 1.
    var playbackFraction: Double {
        duration > 0 ? currentTime / duration : 0
    }
}

private struct ChildSeekBar: View {
    let progress: Double
    /// Spoken position, e.g. "1:23".
    let valueDescription: String
    let onSeek: (Double) -> Void

    /// VoiceOver's increment/decrement step, as a fraction of the video.
    private static let accessibilityStep = 0.05

    @State private var isDragging = false
    @State private var dragProgress: Double = 0

    private var displayProgress: Double {
        isDragging ? dragProgress : progress
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 10)

                Capsule()
                    .fill(.white)
                    .frame(
                        width: max(0, geometry.size.width * displayProgress),
                        height: 10
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 28, height: 28)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(
                        x: max(0, min(
                            geometry.size.width * displayProgress - 14,
                            geometry.size.width - 28
                        ))
                    )
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging { isDragging = true }
                        let ratio = value.location.x / geometry.size.width
                        dragProgress = min(max(ratio, 0), 1)
                    }
                    .onEnded { value in
                        let ratio = value.location.x / geometry.size.width
                        let clamped = min(max(ratio, 0), 1)
                        onSeek(clamped)
                        isDragging = false
                    }
            )
        }
        .frame(height: 48)
        // The drag is unreachable under VoiceOver; expose the bar as an
        // adjustable control instead.
        .accessibilityElement()
        .accessibilityLabel(String.localised("video.seekBar", table: .videos))
        .accessibilityValue(valueDescription)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                onSeek(min(progress + Self.accessibilityStep, 1))
            case .decrement:
                onSeek(max(progress - Self.accessibilityStep, 0))
            @unknown default:
                break
            }
        }
    }
}
#endif
