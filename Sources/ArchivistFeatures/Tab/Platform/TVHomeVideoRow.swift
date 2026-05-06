#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeVideoRow: View {
    static let maxItems = 10

    let title: String
    let icon: String
    let videos: [VideoResponse]
    let serverConfig: ServerConfig
    let onVideoTapped: (VideoResponse) -> Void
    let onViewAll: () -> Void

    var body: some View {
        TVHomeSectionContainer(
            title: title,
            icon: icon,
            onViewAll: onViewAll
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(videos.prefix(Self.maxItems), id: \.videoId) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: serverConfig
                        ) {
                            onVideoTapped(video)
                        }
                        .frame(width: 400)
                    }

                    if videos.count > 0 {
                        TVHomeViewAllCard(action: onViewAll)
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
