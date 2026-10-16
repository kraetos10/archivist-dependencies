#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension VideoDetailScreen {
    var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                send(.commentsHeaderTapped, animation: .default)
            } label: {
                HStack {
                    Text(String.localised("generic.comments", table: .generic))
                        .font(.headline)
                        .foregroundStyle(Color.Text.primary)

                    if !store.comments.isEmpty {
                        Text("\(store.commentCount)")
                            .font(.subheadline)
                            .foregroundStyle(Color.Brand.secondary)
                    }

                    Spacer()

                    Image(
                        systemName: store.showAllComments
                            ? "chevron.down"
                            : "chevron.right"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if store.isLoadingComments {
                CommentCardView(comment: .placeholder)
                    .redacted(reason: .placeholder)
                    .background(Color.Surface.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if store.showAllComments {
                LazyVStack(spacing: 0) {
                    // `Array(...)`: `EnumeratedSequence` is only a
                    // collection from iOS 26, and this package targets 18.
                    ForEach(
                        Array(store.comments.enumerated()),
                        id: \.element.commentId
                    ) { index, comment in
                        commentThread(comment)
                        if index < store.comments.count - 1 {
                            Divider()
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .background(Color.Surface.highlight)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else if let first = store.comments.first {
                CommentCardView(comment: first)
                    .background(Color.Surface.highlight)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// A comment, then its replies behind a collapsed "N replies" toggle.
    @ViewBuilder
    private func commentThread(_ comment: VideoComment) -> some View {
        CommentCardView(comment: comment)

        if comment.replyCount > 0 {
            let isExpanded = store.expandedThreadIDs.contains(comment.id)
            Button {
                send(.repliesToggled(commentId: comment.id), animation: .default)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .accessibilityHidden(true)
                    Text(String.localised("video.comment.replies \(comment.replyCount)", table: .videos))
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(Color.Accent.dark)
                .padding(.leading, 54)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(
                isExpanded
                    ? String.localised("generic.expanded", table: .generic)
                    : String.localised("generic.collapsed", table: .generic)
            )

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(comment.flattenedReplies) { reply in
                        CommentCardView(comment: reply, isReply: true)
                    }
                }
                // Indented under the parent's avatar, with a thread line
                // down the leading edge.
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.Brand.secondary.opacity(0.3))
                        .frame(width: 2)
                        .accessibilityHidden(true)
                }
                .padding(.leading, 28)
                .padding(.bottom, 8)
            }
        }
    }
}
#endif
