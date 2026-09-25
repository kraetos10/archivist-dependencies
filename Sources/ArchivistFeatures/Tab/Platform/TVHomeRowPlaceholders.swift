#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

/// Loading stand-ins for the home rows. Disabled so they can't take focus:
/// focus parked on a placeholder is lost when the real row replaces it.
struct TVHomeVideoRowPlaceholder: View {
    let title: String
    let icon: String
    let serverConfig: ServerConfig

    var body: some View {
        TVHomeSectionContainer(title: title, icon: icon) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    ForEach(VideoResponse.placeholders.prefix(5)) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: serverConfig
                        )
                        .frame(width: TVLayout.cardWidth)
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollClipDisabled()
            .disabled(true)
        }
    }
}

struct TVHomeChannelsRowPlaceholder: View {
    let serverConfig: ServerConfig

    var body: some View {
        TVHomeSectionContainer(
            title: String.localised("generic.channels", table: .generic),
            icon: "antenna.radiowaves.left.and.right"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                    ForEach(ChannelResponse.placeholders) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .scrollClipDisabled()
            .disabled(true)
        }
    }
}
#endif
