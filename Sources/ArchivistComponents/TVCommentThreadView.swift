#if os(tvOS)
import ArchivistNetworking
import SwiftUI

/// A comment opened full screen on Apple TV: the comment in focusable
/// paragraphs, then its replies behind an "N replies" button, as on the
/// phone. Each reply is a focusable row, so the remote can scroll the
/// whole thread.
public struct TVCommentThreadView: View {
    let comment: VideoComment
    /// The comment's text cut into paragraphs by the caller.
    let blocks: [String]
    let isRepliesExpanded: Bool
    let onToggleReplies: () -> Void

    public init(
        comment: VideoComment,
        blocks: [String],
        isRepliesExpanded: Bool,
        onToggleReplies: @escaping () -> Void
    ) {
        self.comment = comment
        self.blocks = blocks
        self.isRepliesExpanded = isRepliesExpanded
        self.onToggleReplies = onToggleReplies
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                TVCommentHeader(comment: comment, avatarSize: 64)
                    .font(.title3)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                ForEach(blocks.indices, id: \.self) { index in
                    TVDescriptionBlock(text: blocks[index])
                }

                if comment.replyCount > 0 {
                    repliesButton
                        .padding(.top, 24)

                    if isRepliesExpanded {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(comment.flattenedReplies) { reply in
                                TVReplyRow(reply: reply)
                            }
                        }
                        // Indented under the comment, with a thread line
                        // down the leading edge.
                        .padding(.leading, 32)
                        .overlay(alignment: .leading) {
                            Rectangle()
                                .fill(Color.Brand.secondary.opacity(0.4))
                                .frame(width: 3)
                                .padding(.leading, 56)
                                .accessibilityHidden(true)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .frame(maxWidth: 1200, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.vertical, TVLayout.rowVerticalPadding)
        }
        .scrollIndicators(.hidden)
        .background(Color.Brand.primary.ignoresSafeArea())
    }

    private var repliesButton: some View {
        Button(action: onToggleReplies) {
            HStack(spacing: 12) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isRepliesExpanded ? 90 : 0))
                    .accessibilityHidden(true)
                Text(String.localised("video.comment.replies \(comment.replyCount)", table: .videos))
            }
            .font(.headline)
        }
        .padding(.horizontal, 24)
        .accessibilityValue(
            isRepliesExpanded
                ? String.localised("generic.expanded", table: .generic)
                : String.localised("generic.collapsed", table: .generic)
        )
    }
}

/// Avatar, author, creator badge, date and likes, in the caller's font.
private struct TVCommentHeader: View {
    let comment: VideoComment
    let avatarSize: CGFloat

    var body: some View {
        HStack(spacing: 16) {
            CommentAvatarView(comment: comment, size: avatarSize)

            Text(comment.commentAuthor ?? "")
                .fontWeight(.bold)
                .lineLimit(1)

            if comment.isByUploader {
                CommentCreatorBadge()
            }

            if let date = comment.relativeDate {
                Text(date)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if let likes = comment.commentLikeCount, likes > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "hand.thumbsup.fill")
                        .accessibilityHidden(true)
                    Text(likes.formatted(.number.notation(.compactName)))
                }
                .foregroundStyle(.secondary)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String.localised("video.comment.likes \(likes)", table: .videos))
            }
        }
    }
}

/// One reply, indented under the comment and highlighted when focused.
private struct TVReplyRow: View {
    let reply: VideoComment

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TVCommentHeader(comment: reply, avatarSize: 44)
                .font(.callout)

            Text(reply.commentText ?? "")
                .font(.body)
                .foregroundStyle(isFocused ? Color.Text.primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            Color.Surface.highlight.opacity(isFocused ? 1 : 0),
            in: RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
        )
        .padding(.leading, 48)
        .focusable()
        .focused($isFocused)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .accessibilityElement(children: .combine)
    }
}
#endif
