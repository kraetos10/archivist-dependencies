#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension VideoDetailScreen {

    // MARK: - Compact: Play Next (horizontal scroll)

    var compactPlayNextSection: some View {
        Group {
            if !store.playNextItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String.localised("video.playNext", table: .videos))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(store.playNextItems) { item in
                                PlayNextRowView(
                                    title: item.title,
                                    channelName: item.channelName,
                                    thumbUrl: item.thumbUrl,
                                    duration: item.duration,
                                    serverConfig: store.serverConfig
                                ) {
                                    send(
                                        .removeFromPlayNextTapped(item.id),
                                        animation: .default
                                    )
                                }
                                .pressable {
                                    send(.playNextItemTapped(item), animation: .default)
                                }
                                .playNextTransition()
                            }
                        }
                        .animation(
                            .default,
                            value: store.playNextItems.map(\.id)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }
                    .scrollClipDisabled()
                }
            }
        }
    }

    // MARK: - Compact: Next Up (horizontal scroll)

    var compactNextUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String.localised("video.upNext", table: .videos))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(
                        store.nextVideos.prefix(10),
                        id: \.videoId
                    ) { video in
                        SimilarVideoCard(
                            video: video,
                            serverConfig: store.serverConfig
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
                .padding(.vertical, 4)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Compact: Similar Videos (horizontal scroll)

    var compactSimilarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String.localised("video.similarVideos", table: .videos))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            if store.isLoadingSimilar {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(
                            VideoResponse.placeholders.prefix(4)
                        ) { video in
                            SimilarVideoCard(
                                video: video,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            } else if store.similarVideos.isEmpty {
                emptyStateSimilar
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(store.similarVideos) { video in
                            SimilarVideoCard(
                                video: video,
                                serverConfig: store.serverConfig
                            )
                            .pressable {
                                send(.similarVideoTapped(video))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            }
        }
    }
}
#endif
