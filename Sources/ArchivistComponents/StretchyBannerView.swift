import SwiftUI

/// Header image that stretches instead of leaving a gap when the enclosing
/// scroll view is pulled past its top.
///
/// `GeometryReader` is load-bearing here: the effect needs this view's own
/// `minY` inside the scroll view. `containerRelativeFrame` resolves against
/// the scroll view rather than the view itself, so it can't express this.
public struct StretchyBannerView: View {
    private let url: URL?
    private let height: CGFloat

    public init(
        url: URL?,
        height: CGFloat = 180
    ) {
        self.url = url
        self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let stretchOffset = max(geo.frame(in: .scrollView).minY, 0)

            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            StretchyBannerPlaceholder()
                        }
                    }
                } else {
                    StretchyBannerPlaceholder()
                }
            }
            .frame(width: geo.size.width, height: height + stretchOffset)
            .clipped()
            .offset(y: -stretchOffset)
        }
        .frame(height: height)
        // Decorative artwork — the channel or playlist name sits directly
        // below it.
        .accessibilityHidden(true)
    }
}

struct StretchyBannerPlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(Color.Surface.highlight)
    }
}
