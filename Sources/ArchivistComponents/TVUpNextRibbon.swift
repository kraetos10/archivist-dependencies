#if os(tvOS)
import SwiftUI

/// The row of videos under the tvOS player's transport: what could play
/// next. Shown with the controls; Down on the remote moves focus into it,
/// Select plays the focused video, and Up or Menu goes back to the video.
///
/// While not browsing, its cards are disabled so the focus engine leaves
/// the player's press capture alone.
struct TVUpNextRibbon: View {
    let items: [UpNextItem]
    let isBrowsing: Bool
    let onSelect: (UpNextItem) -> Void
    let onExit: () -> Void

    static let cardWidth: CGFloat = 320

    @FocusState private var focusedID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(String.localised("video.upNext", table: .videos))
                    .font(.headline)
                if !isBrowsing {
                    Image(systemName: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(.white.opacity(isBrowsing ? 1 : 0.8))

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 40) {
                    ForEach(items) { item in
                        TVUpNextCard(
                            item: item,
                            isFocused: focusedID == item.id
                        ) {
                            onSelect(item)
                        }
                        .focused($focusedID, equals: item.id)
                        .disabled(!isBrowsing)
                    }
                }
                .padding(.vertical, 24)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .focusSection()
        }
        // Dimmed until it's being browsed, so the video stays the subject.
        .opacity(isBrowsing ? 1 : 0.75)
        .onChange(of: isBrowsing) { _, browsing in
            // The cards enable in this same update; focus can only land on
            // them once they have.
            Task { @MainActor in
                focusedID = browsing ? items.first?.id : nil
            }
        }
        .onMoveCommand { direction in
            if direction == .up { onExit() }
        }
        .onExitCommand(perform: onExit)
    }
}

private struct TVUpNextCard: View {
    let item: UpNextItem
    let isFocused: Bool
    let action: () -> Void

    private static var artworkHeight: CGFloat { TVUpNextRibbon.cardWidth * 9 / 16 }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                artwork
                    .tvCardFocusEffect(isFocused)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(item.channelName)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(width: TVUpNextRibbon.cardWidth, alignment: .leading)
            }
        }
        .buttonStyle(TVCardButtonStyle())
    }

    private var artwork: some View {
        AsyncImage(url: item.thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().aspectRatio(contentMode: .fill)
            default:
                Rectangle().fill(.white.opacity(0.15))
            }
        }
        .frame(width: TVUpNextRibbon.cardWidth, height: Self.artworkHeight)
        .overlay(alignment: .bottomTrailing) {
            if let duration = item.duration {
                Text(duration)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 4))
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
    }
}
#endif
