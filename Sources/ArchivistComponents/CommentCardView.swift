#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct CommentCardView: View {
    public let comment: VideoComment

    public init(comment: VideoComment) {
        self.comment = comment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)

                Text(comment.commentAuthor ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)

                if let date = comment.relativeDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }

                Spacer()

                if let likes = comment.commentLikeCount, likes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption)
                        Text("\(likes)")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.Brand.secondary)
                }
            }

            Text(comment.commentText ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct CommentRowView: View {
    public let comment: VideoComment

    public init(comment: VideoComment) {
        self.comment = comment
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.commentAuthor ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)

                if let date = comment.relativeDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }

                Spacer()

                if let likes = comment.commentLikeCount, likes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption)
                        Text("\(likes)")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.Brand.secondary)
                }

                if comment.commentIsFavorited == true {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Text(comment.commentText ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
        }
        .padding(12)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
#endif
