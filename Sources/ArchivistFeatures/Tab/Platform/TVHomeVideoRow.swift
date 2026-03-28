#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import SwiftUI

struct TVHomeVideoRow: View {
    let title: String
    let videos: [VideoResponse]
    let serverConfig: ServerConfig
    let onVideoTapped: (VideoResponse) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.leading, 48)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 48) {
                    ForEach(videos, id: \.videoId) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: serverConfig
                        ) {
                            onVideoTapped(video)
                        }
                        .frame(width: 400)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 30)
            }
            .scrollClipDisabled()
        }
        .focusSection()
    }
}
#endif
