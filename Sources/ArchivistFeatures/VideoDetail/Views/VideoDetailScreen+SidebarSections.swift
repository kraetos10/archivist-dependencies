#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
internal import SQLiteData
import StructuredQueries
import SwiftUI

extension VideoDetailScreen {

    // MARK: - Sidebar: Play Next (vertical rows)

    func sidebarPlayNextSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String.localised("video.playNext", table: .videos))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
                ForEach(store.playNextItems) { item in
                    sidebarPlayNextRow(item, compact: compact)
                        .playNextTransition()
                }
            }
            .animation(.default, value: store.playNextItems.map(\.id))
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    func sidebarPlayNextRow(
        _ item: PlayNextItem,
        compact: Bool
    ) -> some View {
        let thumbnail = playNextThumbnail(item)
        return Group {
            if compact {
                VStack(alignment: .leading, spacing: 8) {
                    thumbnail
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipped()
                    playNextDetails(item)
                        .padding(.horizontal, 10)
                        .padding(.bottom, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    thumbnail
                        .frame(width: 160, height: 90)
                        .clipped()
                    playNextDetails(item)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 8)
                        .padding(.vertical, 8)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .pressable {
            send(.playNextItemTapped(item), animation: .default)
        }
        .contextMenu {
            Button(role: .destructive) {
                send(
                    .removeFromPlayNextTapped(item.id),
                    animation: .default
                )
            } label: {
                Label(
                    String.localised(
                        "video.removeFromPlayNext",
                        table: .videos
                    ),
                    systemImage: "minus.circle"
                )
            }
        }
    }

    func playNextThumbnail(_ item: PlayNextItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if let thumbPath = item.thumbUrl,
               let thumbURL = store.serverConfig.fullURL(for: thumbPath) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color.Brand.secondary.opacity(0.3))
                    }
                }
            } else {
                Rectangle().fill(Color.Brand.secondary.opacity(0.3))
            }

            if let duration = item.duration {
                Text(duration)
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
    }

    func playNextDetails(_ item: PlayNextItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)

            Text(item.channelName)
                .font(.caption2)
                .foregroundStyle(Color.Brand.secondary)
                .lineLimit(1)

            if let duration = item.duration {
                Text(duration)
                    .font(.caption2)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
    }

    // MARK: - Sidebar: Next Up (vertical rows)

    func sidebarNextUpSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String.localised("video.upNext", table: .videos))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            LazyVStack(spacing: 12) {
                ForEach(
                    store.nextVideos.prefix(10),
                    id: \.videoId
                ) { video in
                    SimilarVideoRow(
                        video: video,
                        serverConfig: store.serverConfig,
                        compact: compact
                    )
                    .contextMenu {
                        Button {
                            send(.addUpNextToPlayNextTapped(video))
                        } label: {
                            Label(
                                String.localised("video.playNext", table: .videos),
                                systemImage: "text.line.first.and.arrowtriangle.forward"
                            )
                        }
                    }
                    .pressable {
                        send(.nextUpVideoTapped(video))
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Sidebar: Similar Videos (vertical rows)

    func sidebarSimilarSection(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String.localised("video.similarVideos", table: .videos))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            if store.isLoadingSimilar {
                LazyVStack(spacing: 12) {
                    ForEach(VideoResponse.placeholders.prefix(4)) { video in
                        SimilarVideoRow(
                            video: video,
                            serverConfig: store.serverConfig,
                            compact: compact
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 16)
            } else if store.similarVideos.isEmpty {
                emptyStateSimilar
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(store.similarVideos) { video in
                        SimilarVideoRow(
                            video: video,
                            serverConfig: store.serverConfig,
                            compact: compact
                        )
                        .pressable {
                            send(.similarVideoTapped(video))
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }
}
#endif
