#if os(iOS)
import SwiftUI
import UIKit
import VLCKit

public struct VLCPlayerView: View {
    @State private var controlsVisible = true
    @State private var hideControlsTask: Task<Void, Never>?
    @State private var isFullscreen = false

    private let playerManager = PlayerManager.shared

    public init() {}

    public var body: some View {
        ZStack {
            playerContent
        }
        .clipped()
        .onAppear {
            scheduleHideControls()
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            playerContent
                .ignoresSafeArea()
                .background(Color.black)
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    OrientationLock.shared.unlock()
                    scheduleHideControls()
                }
                .onDisappear {
                    OrientationLock.shared.lockPortrait()
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

            if controlsVisible {
                controlsOverlay
            } else {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            controlsVisible = true
                        }
                        scheduleHideControls()
                    }
            }
        }
    }

    private var controlsOverlay: some View {
        Color.black.opacity(0.3)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = false
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    isFullscreen.toggle()
                    scheduleHideControls()
                } label: {
                    Image(systemName: isFullscreen
                          ? "arrow.down.right.and.arrow.up.left"
                          : "arrow.up.left.and.arrow.down.right")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .padding(16)
                }
            }
            .overlay {
                HStack(spacing: 40) {
                    Button {
                        playerManager.skipBackward(10)
                        scheduleHideControls()
                    } label: {
                        Image(systemName: "gobackward.10")
                            .font(.title)
                            .foregroundStyle(.white)
                    }

                    Button {
                        playerManager.togglePlayPause()
                        scheduleHideControls()
                    } label: {
                        Image(
                            systemName: playerManager.isPlaying
                                ? "pause.circle.fill"
                                : "play.circle.fill"
                        )
                        .font(.system(size: 56))
                        .foregroundStyle(.white)
                    }

                    Button {
                        playerManager.skipForward(10)
                        scheduleHideControls()
                    } label: {
                        Image(systemName: "goforward.10")
                            .font(.title)
                            .foregroundStyle(.white)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    SeekBar(
                        progress: playerManager.duration > 0
                            ? playerManager.currentTime / playerManager.duration
                            : 0,
                        onDragStarted: {
                            hideControlsTask?.cancel()
                        },
                        onSeek: { value in
                            let target = value * playerManager.duration
                            playerManager.seekTo(target)
                            scheduleHideControls()
                        }
                    )

                    HStack {
                        Text(formatTime(playerManager.currentTime))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                        Spacer()
                        Text(formatTime(playerManager.duration))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
    }

    private func scheduleHideControls() {
        hideControlsTask?.cancel()
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                controlsVisible = false
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "-" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
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
        _ = manager.activePlayerSurfaceRole
        _ = manager.persistentVLCDrawable
        return VLCDrawableHostRepresentable(
            shouldAdopt: manager.activePlayerSurfaceRole == role
        )
    }
}

private struct VLCDrawableHostRepresentable: UIViewRepresentable {
    var shouldAdopt: Bool

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

        // Pull it off any previous host and pin it into this one.
        drawable.removeFromSuperview()
        drawable.translatesAutoresizingMaskIntoConstraints = false
        addSubview(drawable)
        NSLayoutConstraint.activate([
            drawable.topAnchor.constraint(equalTo: topAnchor),
            drawable.bottomAnchor.constraint(equalTo: bottomAnchor),
            drawable.leadingAnchor.constraint(equalTo: leadingAnchor),
            drawable.trailingAnchor.constraint(equalTo: trailingAnchor),
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
                    .frame(height: 4)

                Capsule()
                    .fill(.white)
                    .frame(
                        width: max(0, geometry.size.width * displayProgress),
                        height: 4
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: max(0, min(
                            geometry.size.width * displayProgress - 7,
                            geometry.size.width - 14
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
        .frame(height: 30)
    }
}
#endif
