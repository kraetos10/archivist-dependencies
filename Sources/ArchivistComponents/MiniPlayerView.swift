#if os(iOS)
import SwiftUI

// MARK: - Mini Player View

/// Small floating mini player that hosts ONLY the persistent player surface
/// (AVPlayerViewController or VLC drawable) — never the surrounding video
/// detail screen. Reparenting the persistent surface from the full container
/// into this view leaves playback uninterrupted.
public struct MiniPlayerView: View {
    public let title: String
    public let useVLC: Bool
    public let onTap: () -> Void
    public let onClose: () -> Void

    public init(
        title: String,
        useVLC: Bool,
        onTap: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.useVLC = useVLC
        self.onTap = onTap
        self.onClose = onClose
    }

    public var body: some View {
        ZStack {
            Color.black

            playerSurface
                .allowsHitTesting(false)

            // Tap-to-expand layer covers the whole mini player; the close
            // button sits on top of it via overlay.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(perform: onTap)

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
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    @ViewBuilder
    private var playerSurface: some View {
        if useVLC {
            VLCVideoRenderView(role: .mini)
        } else {
            AVPlayerViewControllerWrapper(role: .mini, showsPlaybackControls: false)
        }
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
        case .topLeading:     return CGPoint(x: leftX,  y: topY)
        case .topTrailing:    return CGPoint(x: rightX, y: topY)
        case .bottomLeading:  return CGPoint(x: leftX,  y: bottomY)
        case .bottomTrailing: return CGPoint(x: rightX, y: bottomY)
        }
    }

    static func nearest(
        to point: CGPoint,
        in container: CGSize
    ) -> MiniPlayerCorner {
        let isLeft = point.x + 0.5 < container.width / 2
        let isTop = point.y + 0.5 < container.height / 2
        switch (isTop, isLeft) {
        case (true,  true):  return .topLeading
        case (true,  false): return .topTrailing
        case (false, true):  return .bottomLeading
        case (false, false): return .bottomTrailing
        }
    }
}

// MARK: - Draggable Mini Player Overlay

/// Positions a `MiniPlayerView` at one of the four corners and lets the user
/// drag it to a different corner. Drag uses `.offset` (cheap, no relayout)
/// and snaps to the nearest corner on release.
public struct DraggableMiniPlayerOverlay<Content: View>: View {
    public let miniSize: CGSize
    public let bottomInset: CGFloat
    public let content: Content

    @State private var corner: MiniPlayerCorner = .bottomTrailing
    @State private var dragTranslation: CGSize = .zero

    public init(
        miniSize: CGSize,
        bottomInset: CGFloat = 60,
        @ViewBuilder content: () -> Content
    ) {
        self.miniSize = miniSize
        self.bottomInset = bottomInset
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            let origin = corner.origin(
                in: geo.size,
                miniSize: miniSize,
                padding: 12,
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
