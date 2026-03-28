#if !os(tvOS)
import ArchivistNetworking
import SwiftUI

public struct CommentsSheet: View {
    public let comments: [VideoComment]
    public let onDismiss: () -> Void

    public init(
        comments: [VideoComment],
        onDismiss: @escaping () -> Void
    ) {
        self.comments = comments
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(comments, id: \.commentId) { comment in
                        CommentRowView(comment: comment)
                    }
                }
                .padding(16)
            }
            .background(Color.Brand.primary)
            .navigationTitle(String.localised("generic.comments", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
            }
        }
    }
}
#endif
