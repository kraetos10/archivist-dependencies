import SwiftUI

public struct VideoRowView: View {
    public let title: String
    public let subtitle: String?
    public let secondarySubtitle: String?
    public let thumbnailURL: URL?
    public let badge: String?
    public let thumbnailWidth: CGFloat

    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(
        title: String,
        subtitle: String? = nil,
        secondarySubtitle: String? = nil,
        thumbnailURL: URL? = nil,
        badge: String? = nil,
        thumbnailWidth: CGFloat = 120
    ) {
        self.title = title
        self.subtitle = subtitle
        self.secondarySubtitle = secondarySubtitle
        self.thumbnailURL = thumbnailURL
        self.badge = badge
        self.thumbnailWidth = thumbnailWidth
    }

    private var effectiveWidth: CGFloat {
        sizeClass == .regular ? thumbnailWidth * 1.25 : thumbnailWidth
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView
            textContent
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var thumbnailHeight: CGFloat {
        effectiveWidth * 9 / 16
    }

    private var thumbnailView: some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbnailURL {
                AsyncImage(url: thumbnailURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fit)
                    default:
                        thumbnailPlaceholder
                    }
                }
            } else {
                thumbnailPlaceholder
            }

            if let badge {
                Text(badge)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(6)
            }
        }
        .frame(width: effectiveWidth, height: thumbnailHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var thumbnailPlaceholder: some View {
        Color.Brand.secondary.opacity(0.3)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(sizeClass == .regular ? .body : .subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(3)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .foregroundStyle(Color.Brand.secondary)
            }

            if let secondarySubtitle, !secondarySubtitle.isEmpty {
                Text(secondarySubtitle)
                    .font(sizeClass == .regular ? .subheadline : .caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
    }
}
