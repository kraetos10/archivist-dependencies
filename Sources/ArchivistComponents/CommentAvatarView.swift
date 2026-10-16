import ArchivistNetworking
import SwiftUI

/// A comment author's avatar, falling back to their initial on a tinted
/// circle — the YouTube-hosted image is often gone by the time an archived
/// comment is read. Decorative: the author's name always sits beside it.
public struct CommentAvatarView: View {
    let comment: VideoComment
    let size: CGFloat

    public init(
        comment: VideoComment,
        size: CGFloat
    ) {
        self.comment = comment
        self.size = size
    }

    public var body: some View {
        AsyncImage(url: comment.authorThumbnailURL) { phase in
            if case .success(let image) = phase {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                Circle()
                    .fill(Color.Surface.highlight)
                    .overlay {
                        Text(comment.authorInitial)
                            .font(.system(size: size * 0.45, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.Brand.secondary)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// "Creator" pill beside a comment from the video's own channel.
public struct CommentCreatorBadge: View {
    public init() {}

    public var body: some View {
        Text(String.localised("video.comment.creator", table: .videos))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.Accent.dark, in: Capsule())
    }
}
