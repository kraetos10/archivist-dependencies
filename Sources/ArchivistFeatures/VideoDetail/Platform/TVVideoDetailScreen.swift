#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Dependencies
import SQLiteData
import StructuredQueries
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct TVVideoDetailScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>

    @FetchAll(PlayNextItem.all.order(by: \.id))
    private var playNextItems

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Top: thumbnail + info side by side
                HStack(alignment: .top, spacing: 48) {
                    // Thumbnail
                    thumbnailView
                        .frame(width: 640, height: 360)

                    // Info
                    VStack(alignment: .leading, spacing: 16) {
                        Text(store.video.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .lineLimit(3)

                        HStack(spacing: 8) {
                            Text(store.video.channelName)
                                .fontWeight(.semibold)

                            if let views = store.video.formattedViewCount {
                                Text("·")
                                Text("\(views) views")
                            }

                            if let published = store.video.publishedRelative {
                                Text("·")
                                Text(published)
                            }

                            if let duration = store.video.durationStr {
                                Text("·")
                                Text(duration)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.secondary)

                        Button {
                            send(.playTapped)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: store.video.watchProgress > 0 ? "play.circle.fill" : "play.fill")
                                Text(store.video.watchProgress > 0 ? String(localized: "Resume") : String(localized: "Play"))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            send(.toggleWatchedTapped)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: store.isWatched ? "eye.fill" : "eye")
                                Text(store.isWatched ? String(localized: "Watched") : String(localized: "Mark as Watched"))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.bordered)

                        if let description = store.video.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(store.isDescriptionExpanded ? nil : 4)

                            Button {
                                send(.toggleDescription, animation: .default)
                            } label: {
                                Text(store.isDescriptionExpanded ? String(localized: "Show Less") : String(localized: "Show More"))
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 48)
                .padding(.top, 32)

                // Play Next
                if store.showPlayNext && !playNextItems.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "Play Next"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal, 48)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 40) {
                                ForEach(playNextItems) { item in
                                    playNextCard(item)
                                        .playNextTransition()
                                }
                            }
                            .animation(.default, value: playNextItems.map(\.id))
                            .padding(.horizontal, 48)
                        }
                    }
                    .padding(.top, 48)
                    .padding(.bottom, 24)
                }

                // Up Next
                if !store.nextVideos.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "Up Next"))
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal, 48)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 40) {
                                ForEach(store.nextVideos.prefix(10)) { video in
                                    TVVideoCardView(
                                        video: video,
                                        serverConfig: store.serverConfig
                                    ) {
                                        send(.nextUpVideoTapped(video))
                                    }
                                }
                            }
                            .padding(.horizontal, 48)
                        }
                    }
                    .padding(.bottom, 24)
                }

                // Bottom: similar videos horizontal scroll
                similarSection
                    .padding(.top, 48)
                    .padding(.bottom, 80)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { store.isPlaying },
            set: { if !$0 { send(.stopPlayback) } }
        )) {
            ZStack {
                TVPlayerView {
                    send(.stopPlayback)
                }
                .ignoresSafeArea()
            }
            .onExitCommand {
                send(.stopPlayback)
            }
        }
        .onAppear { send(.viewDidAppear) }
    }

    // MARK: - Thumbnail

    private var thumbnailView: some View {
        ZStack {
            if let thumbPath = store.video.vidThumbUrl,
               let thumbURL = store.serverConfig.fullURL(for: thumbPath) {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(.secondary.opacity(0.3))
                    }
                }
            } else {
                Rectangle().fill(.secondary.opacity(0.3))
            }

            if store.video.watchProgress > 0 {
                VStack {
                    Spacer()
                    WatchProgressBar(progress: store.video.watchProgress, height: 6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Play Next Card

    private func playNextCard(_ item: PlayNextItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(width: 400, height: 225)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(item.title)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(item.channelName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 400)
        .contextMenu {
            Button(role: .destructive) {
                send(.removeFromPlayNextTapped(item.id), animation: .default)
            } label: {
                Label(String(localized: "Remove from Play Next"), systemImage: "minus.circle")
            }
        }
    }

    // MARK: - Similar Videos

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text(String(localized: "Similar Videos"))
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 48)

            if store.isLoadingSimilar {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 32) {
                        ForEach(VideoResponse.placeholders.prefix(4)) { video in
                            TVVideoCardView(
                                video: video,
                                serverConfig: store.serverConfig
                            )
                            .frame(width: 400)
                            .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.horizontal, 48)
                }
            } else if store.similarVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text(String(localized: "No similar videos found"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 32) {
                        ForEach(store.similarVideos) { video in
                            TVVideoCardView(
                                video: video,
                                serverConfig: store.serverConfig
                            ) {
                                send(.similarVideoTapped(video))
                            }
                            .frame(width: 400)
                        }
                    }
                    .padding(.horizontal, 48)
                    .padding(.vertical, 24)
                }
            }
        }
    }
}
#endif
