#if os(tvOS)
import ArchivistNetworking
import SwiftUI

/// A comment in the tvOS video detail's comments row: author, date, likes
/// and the first lines of the text. Pressing it opens the whole comment.
/// Fixed size, so a row of comments lines up whatever their length.
public struct TVCommentCard: View {
    let comment: VideoComment
    let action: () -> Void

    public static let width: CGFloat = 560
    private static let height: CGFloat = 230

    public init(
        comment: VideoComment,
        action: @escaping () -> Void
    ) {
        self.comment = comment
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                header

                Text(comment.commentText ?? "")
                    .font(.callout)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .frame(
                width: Self.width - 48,
                height: Self.height - 48,
                alignment: .topLeading
            )
        }
        .buttonStyle(TVPanelButtonStyle())
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(comment.commentAuthor ?? "")
                .font(.headline)
                .lineLimit(1)
                .layoutPriority(1)

            if let date = comment.relativeDate {
                Text(date)
                    .font(.subheadline)
                    .opacity(0.7)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if comment.commentIsFavorited == true {
                Image(systemName: "heart.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .accessibilityLabel(String.localised("video.comment.favorited", table: .videos))
            }

            if let likes = comment.commentLikeCount, likes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup.fill")
                        .accessibilityHidden(true)
                    Text(likes.formatted(.number.notation(.compactName)))
                }
                .font(.subheadline)
                .opacity(0.7)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String.localised("video.comment.likes \(likes)", table: .videos))
            }
        }
    }
}
#endif
