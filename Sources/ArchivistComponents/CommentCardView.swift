#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct CommentCardView: View {
    public let comment: VideoComment
    /// A reply sits indented under its comment, with a smaller avatar.
    public let isReply: Bool

    public init(
        comment: VideoComment,
        isReply: Bool = false
    ) {
        self.comment = comment
        self.isReply = isReply
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 10) {
            CommentAvatarView(comment: comment, size: isReply ? 24 : 32)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(comment.commentAuthor ?? "")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Text.primary)
                        .lineLimit(1)

                    if comment.isByUploader {
                        CommentCreatorBadge()
                    }

                    if let date = comment.relativeDate {
                        Text(date)
                            .font(.caption)
                            .foregroundStyle(Color.Brand.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if let likes = comment.commentLikeCount, likes > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.caption)
                                .accessibilityHidden(true)
                            Text(likes.formatted(.number.notation(.compactName)))
                                .font(.caption)
                        }
                        .foregroundStyle(Color.Brand.secondary)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(String.localised("video.comment.likes \(likes)", table: .videos))
                    }

                    if comment.commentIsFavorited == true {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                            .accessibilityLabel(String.localised("video.comment.favorited", table: .videos))
                    }
                }

                Text(comment.commentText ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.primary)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
