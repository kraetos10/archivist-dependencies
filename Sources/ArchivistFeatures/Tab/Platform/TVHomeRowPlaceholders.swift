#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeVideoRowPlaceholder: View {
    let title: String
    let icon: String
    let serverConfig: ServerConfig

    var body: some View {
        TVHomeSectionContainer(title: title, icon: icon) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(VideoResponse.placeholders.prefix(5)) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: serverConfig
                        )
                        .frame(width: 400)
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
    }
}

struct TVHomeChannelsRowPlaceholder: View {
    let serverConfig: ServerConfig

    var body: some View {
        TVHomeSectionContainer(
            title: String(localized: "Channels"),
            icon: "antenna.radiowaves.left.and.right"
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(ChannelResponse.placeholders) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
    }
}
#endif
