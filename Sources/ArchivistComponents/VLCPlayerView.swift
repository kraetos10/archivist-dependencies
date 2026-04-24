#if os(iOS)
import SwiftUI
import UIKit
import VLCKit

public struct VLCPlayerView: View {
    @Bindable private var playerManager = PlayerManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            playerContent
        }
        .clipped()
        .onAppear {
            playerManager.scheduleHideVLCControls()
        }
        .fullScreenCover(isPresented: $playerManager.isVLCFullscreen) {
            playerContent
                .ignoresSafeArea()
                .background(Color.black)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    playerManager.scheduleHideVLCControls()
                }
        }
    }

    private var playerContent: some View {
        ZStack {
            VLCVideoRenderView()
                .allowsHitTesting(false)

            if playerManager.isBuffering && !playerManager.isPlaying {
                Color.black.opacity(0.4)
                    .allowsHitTesting(false)
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                    .allowsHitTesting(false)
            }

            if playerManager.vlcControlsVisible {
                controlsOverlay
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        playerManager.showVLCControls()
                    }
            }
        }
    }

    private var controlsOverlay: some View {
        Color.black.opacity(0.35)
            .contentShape(Rectangle())
            .onTapGesture {
                playerManager.hideVLCControls()
            }
            .overlay(alignment: .topTrailing) {
                roundedControlButton(
                    systemImage: playerManager.isVLCFullscreen
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right",
                    iconSize: 18,
                    padding: 12
                ) {
                    playerManager.toggleVLCFullscreen()
                }
                .padding(16)
            }
            .overlay { centerTransportControls }
            .overlay(alignment: .bottom) { bottomInfoAndSeek }
    }

    // MARK: - Center transport

    private var centerTransportControls: some View {
        HStack(spacing: 36) {
            roundedControlButton(
                systemImage: "backward.end.fill",
                iconSize: 24,
                padding: 18,
                isEnabled: playerManager.canGoPrevious
            ) {
                playerManager.onPreviousRequested?()
                playerManager.scheduleHideVLCControls()
            }

            roundedControlButton(
                systemImage: playerManager.isPlaying ? "pause.fill" : "play.fill",
                iconSize: 34,
                padding: 22
            ) {
                playerManager.togglePlayPause()
                playerManager.scheduleHideVLCControls()
            }

            roundedControlButton(
                systemImage: "forward.end.fill",
                iconSize: 24,
                padding: 18
            ) {
                playerManager.onNextRequested?()
                playerManager.scheduleHideVLCControls()
            }
        }
    }

    private func roundedControlButton(
        systemImage: String,
        iconSize: CGFloat,
        padding: CGFloat,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: iconSize + padding * 2, height: iconSize + padding * 2)
                .background(.black.opacity(0.45))
                .background(.ultraThinMaterial.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }

    // MARK: - Bottom info + seek bar

    private var bottomInfoAndSeek: some View {
        VStack(alignment: .leading, spacing: 10) {
            titleRow

            SeekBar(
                progress: playerManager.duration > 0
                    ? playerManager.currentTime / playerManager.duration
                    : 0,
                onDragStarted: {
                    playerManager.cancelVLCHideControls()
                },
                onSeek: { value in
                    let target = value * playerManager.duration
                    playerManager.seekTo(target)
                    playerManager.scheduleHideVLCControls()
                }
            )

            HStack {
                Text(playerManager.currentTimeDisplay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(playerManager.durationDisplay)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    @ViewBuilder
    private var titleRow: some View {
        if playerManager.isVLCFullscreen, let metadata = playerManager.currentMetadata {
            HStack(spacing: 10) {
                if let thumbURL = metadata.channelThumbURL {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Circle().fill(.white.opacity(0.2))
                        }
                    }
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                }
                Text(metadata.artist)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("·")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                Text(metadata.title)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - VLC Video Render View

/// Hosts the persistent `VLCPiPDrawableView` owned by `PlayerManager` for a
/// specific role. Only the host whose role matches
/// `PlayerManager.activePlayerSurfaceRole` adopts the drawable; the other
/// shows nothing. Same anti-race pattern as `AVPlayerViewControllerWrapper`.
public struct VLCVideoRenderView: View {
    public var role: PlayerSurfaceRole

    public init(role: PlayerSurfaceRole = .fullDetail) {
        self.role = role
    }

    public var body: some View {
        let manager = PlayerManager.shared
        _ = manager.persistentVLCDrawable
        // Passing `isVLCFullscreen` as a property forces SwiftUI to call
        // `updateUIView` on both hosts when the fullscreen cover toggles —
        // otherwise the underlying host keeps its stale "I don't own the
        // drawable" state after the cover dismisses and renders black.
        return VLCDrawableHostRepresentable(
            shouldAdopt: manager.activePlayerSurfaceRole == role,
            fullscreenToken: manager.isVLCFullscreen
        )
    }
}

private struct VLCDrawableHostRepresentable: UIViewRepresentable {
    var shouldAdopt: Bool
    var fullscreenToken: Bool

    func makeUIView(context: Context) -> VLCDrawableHostView {
        let host = VLCDrawableHostView()
        host.backgroundColor = .black
        return host
    }

    func updateUIView(_ host: VLCDrawableHostView, context: Context) {
        if shouldAdopt {
            host.adoptPersistentDrawable()
        } else {
            host.detachPersistentDrawable()
        }
    }

    static func dismantleUIView(_ host: VLCDrawableHostView, coordinator: ()) {
        host.detachPersistentDrawable()
    }
}

/// Container UIView that adopts the persistent `VLCPiPDrawableView` from
/// `PlayerManager` as a pinned subview. Reparenting the drawable between
/// hosts is what makes the mini player ↔ full transition seamless for VLC.
public final class VLCDrawableHostView: UIView {
    func adoptPersistentDrawable() {
        guard let drawable = PlayerManager.shared.persistentVLCDrawable else { return }

        if drawable.superview === self { return }

        // `addSubview` already removes the drawable from any previous host.
        // Avoid an explicit `removeFromSuperview` first — that intermediate
        // orphaned state was making VLC pause its video output, causing a
        // black surface after reparenting.
        drawable.translatesAutoresizingMaskIntoConstraints = false
        addSubview(drawable)
        NSLayoutConstraint.activate([
            drawable.topAnchor.constraint(equalTo: topAnchor),
            drawable.bottomAnchor.constraint(equalTo: bottomAnchor),
            drawable.leadingAnchor.constraint(equalTo: leadingAnchor),
            drawable.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func detachPersistentDrawable() {
        guard let drawable = PlayerManager.shared.persistentVLCDrawable,
              drawable.superview === self else { return }
        drawable.removeFromSuperview()
    }
}

// MARK: - VLC PiP Drawable View

public class VLCPiPDrawableView: UIView, VLCPictureInPictureDrawable, VLCPictureInPictureMediaControlling {
    nonisolated(unsafe) weak var mediaPlayer: VLCMediaPlayer?
    nonisolated(unsafe) weak var backend: VLCPlayerBackend?
    nonisolated(unsafe) private weak var pipController: VLCPictureInPictureWindowControlling?

    // MARK: - VLCPictureInPictureDrawable

    nonisolated public func mediaController() -> (any VLCPictureInPictureMediaControlling)? {
        self
    }

    nonisolated public func pictureInPictureReady() -> ((any VLCPictureInPictureWindowControlling)?) -> Void {
        { [weak self] controller in
            guard let self else { return }
            self.pipController = controller

            controller?.stateChangeEventHandler = { [weak self] isStarted in
                guard let self, let backend = self.backend else { return }
                Task { @MainActor in
                    if isStarted {
                        backend.onPiPStarted?()
                        PlayerManager.shared.isInPiP = true
                    } else {
                        PlayerManager.shared.isInPiP = false
                        backend.pipDrawableRetain = nil
                        backend.onPiPStopped?()
                    }
                }
            }

            if let controller {
                nonisolated(unsafe) let sendableController = controller
                Task { @MainActor in
                    self.backend?.pipController = sendableController
                }
            }
        }
    }

    // MARK: - VLCPictureInPictureMediaControlling

    nonisolated public func play() {
        mediaPlayer?.play()
    }

    nonisolated public func pause() {
        mediaPlayer?.pause()
    }

    nonisolated public func seek(by offset: Int64, completion: (() -> Void)!) {
        mediaPlayer?.jump(withOffset: Int32(offset), completion: completion)
    }

    nonisolated public func mediaLength() -> Int64 {
        mediaPlayer?.media?.length.value?.int64Value ?? 0
    }

    nonisolated public func mediaTime() -> Int64 {
        mediaPlayer?.time.value?.int64Value ?? 0
    }

    nonisolated public func isMediaSeekable() -> Bool {
        mediaPlayer?.isSeekable == true
    }

    nonisolated public func isMediaPlaying() -> Bool {
        mediaPlayer?.isPlaying == true
    }
}

// MARK: - Seek Bar

private struct SeekBar: View {
    let progress: Double
    var onDragStarted: (() -> Void)?
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
                    .frame(height: 6)

                Capsule()
                    .fill(.white)
                    .frame(
                        width: max(0, geometry.size.width * displayProgress),
                        height: 6
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
                    .offset(
                        x: max(0, min(
                            geometry.size.width * displayProgress - 9,
                            geometry.size.width - 18
                        ))
                    )
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            onDragStarted?()
                        }
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
        .frame(height: 36)
    }
}
#endif
