#if os(tvOS)
import SwiftUI

// Shared pieces of the tvOS detail screens (video, channel, playlist).

/// The banner atop a tvOS detail screen: inset within the safe area with
/// the same rounded corners as card artwork, so it reads as deliberate
/// rather than a full-bleed image that stopped short of the edges.
public struct TVDetailBannerView: View {
    let url: URL?

    private static let height: CGFloat = 300

    public init(url: URL?) {
        self.url = url
    }

    public var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Self.height)
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
        // Decorative artwork; the title beneath it names the screen.
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.2))
    }
}

/// A clamped description preview that opens the full text. On tvOS an
/// in-place expansion leaves the extra text unreachable — there's nothing
/// focusable in it to scroll to — so the full text gets its own screen
/// (`TVFullDescriptionView`).
public struct TVDescriptionCard: View {
    let text: String
    let action: () -> Void

    public init(
        text: String,
        action: @escaping () -> Void
    ) {
        self.text = text
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Text(text)
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(String.localised("generic.showMore", table: .generic))
                    .font(.callout)
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(TVDescriptionCardButtonStyle())
        .frame(maxWidth: 1200, alignment: .leading)
    }
}

/// Same focus convention as `TVCapsuleButtonStyle`: white fill with dark
/// text when focused, the highlight surface otherwise.
private struct TVDescriptionCardButtonStyle: ButtonStyle {
    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isFocused ? Color.black : Color.Text.primary)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                    .fill(isFocused ? Color.white : Color.Surface.highlight)
            )
            .scaleEffect(isFocused ? 1.03 : 1.0)
            .shadow(
                color: .black.opacity(isFocused ? 0.4 : 0),
                radius: isFocused ? 16 : 0,
                y: isFocused ? 10 : 0
            )
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}

/// The full description, presented as a full-screen cover over a detail
/// screen. Each block (see `String.descriptionBlocks()`) is its own focus
/// stop, so swiping moves through the text and the scroll view follows.
/// Menu dismisses.
public struct TVFullDescriptionView: View {
    let title: String
    let blocks: [String]

    public init(
        title: String,
        blocks: [String]
    ) {
        self.title = title
        self.blocks = blocks
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                ForEach(blocks.indices, id: \.self) { index in
                    TVDescriptionBlock(text: blocks[index])
                }
            }
            .frame(maxWidth: 1200, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.vertical, TVLayout.rowVerticalPadding)
        }
        .background(Color.Brand.primary.ignoresSafeArea())
    }
}

private struct TVDescriptionBlock: View {
    let text: String

    @FocusState private var isFocused: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isFocused ? Color.Text.primary : .secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(
                Color.Surface.highlight.opacity(isFocused ? 1 : 0),
                in: RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
            )
            .focusable()
            .focused($isFocused)
            .animation(.easeInOut(duration: 0.15), value: isFocused)
    }
}
#endif
