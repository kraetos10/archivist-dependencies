#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeVideoRowPlaceholder: View {
    let title: String
    let serverConfig: ServerConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
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
                .padding(.vertical, 20)
            }
        }
    }
}

struct TVHomeChannelsRowPlaceholder: View {
    let serverConfig: ServerConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Channels"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 40) {
                    ForEach(ChannelResponse.placeholders) { channel in
                        TVChannelCardView(
                            channel: channel,
                            serverConfig: serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 20)
            }
        }
    }
}
#endif
