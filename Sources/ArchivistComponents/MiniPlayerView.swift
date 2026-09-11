#if os(iOS)
import SwiftUI

// MARK: - Mini Player View

/// Small floating mini player that hosts ONLY the persistent VLC drawable —
/// never the surrounding video detail screen. Reparenting the persistent
/// surface out of the full container and into this view leaves playback
/// uninterrupted, because `PlaybackServiceBackend`'s `VLCMediaPlayer` is
/// never rebuilt.
public struct MiniPlayerView: View {
    public let title: String
    public let onTap: () -> Void
    public let onClose: () -> Void

    public init(
        title: String,
        onTap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.onTap = onTap
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black

            VLCVideoRenderView(role: .mini)
                .allowsHitTesting(false)

            // Tap-to-expand layer covers the whole mini player; the close
            // button sits on top of it via the overlay below.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticFeedback.light.play()
                    onTap()
                }

            VStack {
                Spacer()
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .allowsHitTesting(false)
            }
        }
        // A bare `onTapGesture` carries no traits, so VoiceOver would see
        // the whole stack as static art. Collapse it into one button that
        // expands, and hang the close action off the same element.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(String.localised("video.miniPlayer.expandHint", table: .videos))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            HapticFeedback.light.play()
            onTap()
        }
        .accessibilityAction(named: String.localised("video.miniPlayer.close", table: .videos)) {
            onClose()
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                // Fixed size on purpose: this is player chrome laid out
                // over video, in a container that can't grow with Dynamic
                // Type. The accessibility label below carries the meaning.
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
            .accessibilityLabel(String.localised("video.miniPlayer.close", table: .videos))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

// MARK: - Mini Player Corner

public enum MiniPlayerCorner: Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    func origin(
        in container: CGSize,
        miniSize: CGSize,
        padding: CGFloat,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) -> CGPoint {
        let leftX = padding
        let rightX = container.width - miniSize.width - padding
        let topY = topInset + padding
        let bottomY = container.height - miniSize.height - bottomInset - padding

        switch self {
        case .topLeading:
            return CGPoint(x: leftX, y: topY)
        case .topTrailing:
            return CGPoint(x: rightX, y: topY)
        case .bottomLeading:
            return CGPoint(x: leftX, y: bottomY)
        case .bottomTrailing:
            return CGPoint(x: rightX, y: bottomY)
        }
    }

    static func nearest(
        to point: CGPoint,
        in container: CGSize
    ) -> MiniPlayerCorner {
        let isLeft = point.x + 0.5 < container.width / 2
        let isTop = point.y + 0.5 < container.height / 2
        switch (isTop, isLeft) {
        case (true, true):
            return .topLeading
        case (true, false):
            return .topTrailing
        case (false, true):
            return .bottomLeading
        case (false, false):
            return .bottomTrailing
        }
    }
}

// MARK: - Mini Player Metrics

/// Sizing for the floating mini player.
///
/// A fixed point size can't serve both idioms: 200pt is about half an
/// iPhone's width and a fifth of an iPad's, so what reads as a substantial
/// picture-in-picture on the phone looks like a postage stamp on a 12.9".
/// Taking a share of the container instead keeps it proportionate across
/// both, and across rotation and iPad multitasking, since the container is
/// the window rather than the screen.
///
/// Declared outside `DraggableMiniPlayerOverlay` because Swift doesn't
/// allow static stored properties on a generic type.
enum MiniPlayerMetrics {
    /// Share of the container's width the mini player occupies.
    static let widthFraction: CGFloat = 0.32
    /// Floor, so it stays usable on the narrowest phone — this is what
    /// iPhone sizes land on, preserving the size it has always had there.
    static let minWidth: CGFloat = 200
    /// Ceiling, so a 12.9" in landscape doesn't hand over a third of the
    /// screen to a player the user has just put aside.
    static let maxWidth: CGFloat = 440
    /// Gap between the mini player and the container's edges.
    static let padding: CGFloat = 12

    static func size(in container: CGSize) -> CGSize {
        let preferred = container.width * widthFraction
        let bounded = min(max(preferred, minWidth), maxWidth)
        // The floor can still exceed a very narrow container — a slide-over
        // window, say — so let the container win that argument.
        let width = min(bounded, container.width - padding * 2).rounded()
        return CGSize(width: width, height: (width * 9 / 16).rounded())
    }
}

// MARK: - Draggable Mini Player Overlay

/// Positions a `MiniPlayerView` at one of the four corners and lets the user
/// drag it to a different corner. Drag uses `.offset` (cheap, no relayout)
/// and snaps to the nearest corner on release.
///
/// The mini player's size comes from `MiniPlayerMetrics` rather than the
/// caller, so it scales with the container on every platform without each
/// tab screen having to know the rule.
public struct DraggableMiniPlayerOverlay<Content: View>: View {
    public let bottomInset: CGFloat
    public let content: Content

    @State private var corner: MiniPlayerCorner = .bottomTrailing
    @State private var dragTranslation: CGSize = .zero

    public init(
        bottomInset: CGFloat = 60,
        @ViewBuilder content: () -> Content
    ) {
        self.bottomInset = bottomInset
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            let miniSize = MiniPlayerMetrics.size(in: geo.size)
            let origin = corner.origin(
                in: geo.size,
                miniSize: miniSize,
                padding: MiniPlayerMetrics.padding,
                topInset: geo.safeAreaInsets.top,
                bottomInset: bottomInset
            )
            content
                .frame(width: miniSize.width, height: miniSize.height)
                .offset(
                    x: origin.x + dragTranslation.width,
                    y: origin.y + dragTranslation.height
                )
                .gesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            dragTranslation = value.translation
                        }
                        .onEnded { value in
                            let endOrigin = CGPoint(
                                x: origin.x + value.translation.width,
                                y: origin.y + value.translation.height
                            )
                            let center = CGPoint(
                                x: endOrigin.x + miniSize.width / 2,
                                y: endOrigin.y + miniSize.height / 2
                            )
                            let snapped = MiniPlayerCorner.nearest(
                                to: center,
                                in: geo.size
                            )
                            withAnimation(.spring(duration: 0.3)) {
                                corner = snapped
                                dragTranslation = .zero
                            }
                        }
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}
#endif
