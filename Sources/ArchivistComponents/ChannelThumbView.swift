import SwiftUI

public struct ChannelThumbView: View {
    public let url: URL?
    public let size: CGFloat

    public init(
        url: URL?,
        size: CGFloat = 24
    ) {
        self.url = url
        self.size = size
    }

    public var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    case .failure:
                        failurePlaceholder
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var placeholder: some View {
        Circle()
            .fill(Color.Surface.highlight)
    }

    private var failurePlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.Surface.highlight)
            Image(systemName: "person.fill")
                .font(.system(size: size * 0.45))
                .foregroundStyle(Color.Brand.secondary)
        }
    }
}
