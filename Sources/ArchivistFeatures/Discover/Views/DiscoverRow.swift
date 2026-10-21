#if !os(tvOS)
import ArchivistComponents
import SwiftUI

/// A Discover row in the home page's style: a rounded panel with a header
/// above a sideways strip of cards.
///
/// `resetKey` is what the row is currently about; when it changes the strip
/// scrolls back to the start, so new content isn't entered half-way along.
struct DiscoverRow<Header: View, Subheader: View, Content: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var position = ScrollPosition(edge: .leading)

    let resetKey: AnyHashable
    let header: Header
    let subheader: Subheader
    let content: (_ cardWidth: CGFloat) -> Content

    init(
        resetKey: AnyHashable,
        @ViewBuilder header: () -> Header,
        @ViewBuilder subheader: () -> Subheader,
        @ViewBuilder content: @escaping (_ cardWidth: CGFloat) -> Content
    ) {
        self.resetKey = resetKey
        self.header = header()
        self.subheader = subheader()
        self.content = content
    }

    private var cardWidth: CGFloat {
        horizontalSizeClass == .regular ? 340 : 320
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header
                subheader
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    content(cardWidth)
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollPosition($position)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Surface.highlight)
        )
        .padding(.horizontal, 12)
        .onChange(of: resetKey) {
            withAnimation(.smooth) {
                position.scrollTo(edge: .leading)
            }
        }
    }
}

extension DiscoverRow where Subheader == EmptyView {
    init(
        resetKey: AnyHashable,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: @escaping (_ cardWidth: CGFloat) -> Content
    ) {
        self.init(
            resetKey: resetKey,
            header: header,
            subheader: { EmptyView() },
            content: content
        )
    }
}

// MARK: - Loading placeholders

private extension Color {
    static let skeleton = Color.Brand.secondary.opacity(0.22)
}

/// A card-shaped placeholder with a shimmer, laid out like `DiscoverVideoCard`.
struct DiscoverCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.skeleton)
                .aspectRatio(16 / 9, contentMode: .fit)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeleton)
                .frame(height: 14)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeleton)
                .frame(height: 14)
                .padding(.trailing, 70)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.skeleton)
                .frame(height: 11)
                .padding(.trailing, 120)
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.skeleton)
                .frame(height: 30)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shimmering()
    }
}

/// Placeholder cards filling a row's strip.
struct DiscoverCardSkeletons: View {
    let cardWidth: CGFloat
    var count = 5

    var body: some View {
        ForEach(0..<count, id: \.self) { _ in
            DiscoverCardSkeleton()
                .frame(width: cardWidth)
                .transition(.opacity)
        }
    }
}

/// A whole row of placeholders, shown while the shelves are being built.
struct DiscoverRowSkeleton: View {
    var body: some View {
        DiscoverRow(
            resetKey: 0,
            header: {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.skeleton)
                    .frame(width: 180, height: 18)
                    .shimmering()
            },
            content: { cardWidth in
                DiscoverCardSkeletons(cardWidth: cardWidth)
            }
        )
        .scrollDisabled(true)
        .transition(.opacity)
    }
}
#endif
