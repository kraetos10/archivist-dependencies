#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct ChildVideoPlayerScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>
    @Bindable private var playerManager = PlayerManager.shared
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
            send(.videoChanged)
            overlayShown = true
        }
    }

    @ViewBuilder
    private var playerLayer: some View {
        if store.isPlaying {
            VLCPlayerView()
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    overlayShown.toggle()
                }
        } else {
            thumbnailLayer
        }
    }

    private var thumbnailLayer: some View {
        ZStack {
            Color.black

            if let thumbURL,
               let url = store.serverConfig.fullURL(for: thumbURL) {
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
                .font(.system(size: 72))
                .foregroundStyle(.white.opacity(0.95))
                .shadow(radius: 8)
        }
        .contentShape(Rectangle())
        .onTapGesture { send(.playTapped) }
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
        ScrollView(.horizontal, showsIndicators: false) {
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
        .padding(.vertical, 12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var transportBar: some View {
        HStack(spacing: 16) {
            Button {
                playerManager.togglePlayPause()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            ChildSeekBar(
                progress: playerManager.duration > 0
                    ? playerManager.currentTime / playerManager.duration
                    : 0,
                onSeek: { value in
                    let target = value * playerManager.duration
                    playerManager.seekTo(target)
                }
            )

            Text("\(playerManager.currentTimeDisplay) / \(playerManager.durationDisplay)")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
    }

    private var thumbURL: String? {
        store.video.vidThumbUrl
    }
}

private struct ChildSeekBar: View {
    let progress: Double
    let onSeek: (Double) -> Void

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
    }
}
#endif
