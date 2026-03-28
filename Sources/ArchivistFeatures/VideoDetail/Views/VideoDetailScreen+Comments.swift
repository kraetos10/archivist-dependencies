#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

extension VideoDetailScreen {
    var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation {
                    store.showAllComments.toggle()
                }
            } label: {
                HStack {
                    Text(String.localised("generic.comments", table: .generic))
                        .font(.headline)
                        .foregroundStyle(Color.Text.primary)

                    if !store.comments.isEmpty {
                        Text("\(store.comments.count)")
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
                    ForEach(
                        Array(store.comments.enumerated()),
                        id: \.element.commentId
                    ) { index, comment in
                        CommentCardView(comment: comment)
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
}
#endif
