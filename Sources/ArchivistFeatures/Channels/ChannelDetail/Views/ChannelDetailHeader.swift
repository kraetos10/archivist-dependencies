#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// Banner, avatar, name, subscriber count and the expandable description.
@ViewAction(for: ChannelDetailReducer.self)
struct ChannelDetailHeader: View {
    let store: StoreOf<ChannelDetailReducer>

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var avatarSize: CGFloat {
        horizontalSizeClass == .regular ? 120 : 80
    }

    var body: some View {
        VStack(spacing: 12) {
            StretchyBannerView(url: store.channelBannerURL)

            ChannelThumbView(url: store.channelThumbURL, size: avatarSize)
                .overlay(Circle().stroke(Color.Brand.primary, lineWidth: 3))
                .offset(y: -(avatarSize / 2))
                .padding(.bottom, -(avatarSize / 2))

            Text(store.channel.channelName)
                .font(horizontalSizeClass == .regular ? .title : .title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)

            if let subs = store.channel.formattedSubs {
                Text("\(subs) subscribers")
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
            }

            if let description = store.channel.channelDescription, !description.isEmpty {
                VStack(spacing: 4) {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(Color.Text.primary)
                        .lineLimit(store.isDescriptionExpanded ? nil : 5)
                        .multilineTextAlignment(.center)

                    Button {
                        send(.descriptionToggleTapped, animation: .default)
                    } label: {
                        Text(
                            store.isDescriptionExpanded
                                ? String.localised("generic.showLess", table: .generic)
                                : String.localised("generic.showMore", table: .generic)
                        )
                            .font(.caption)
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
    }
}
#endif
