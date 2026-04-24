#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelDetailReducer.self)
public struct ChannelDetailScreen: View {
    @Bindable public var store: StoreOf<ChannelDetailReducer>

    public init(store: StoreOf<ChannelDetailReducer>) {
        self.store = store
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 400), spacing: 48)]
        #else
        if horizontalSizeClass == .regular {
            [GridItem(.adaptive(minimum: 300), spacing: 16)]
        } else {
            [GridItem(.flexible())]
        }
        #endif
    }

    private var pendingColumns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 300), spacing: 32)]
        #else
        if horizontalSizeClass == .regular {
            [GridItem(.adaptive(minimum: 220), spacing: 12)]
        } else {
            [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        }
        #endif
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                headerView

                Section {
                    videosContent
                } header: {
                    videosSectionHeader
                }

                if !store.pendingDownloads.isEmpty || store.isLoadingDownloads {
                    Section {
                        pendingDownloadsContent
                    } header: {
                        downloadsSectionHeader
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.Brand.primary)
        .refreshable { send(.pullToRefreshTriggered) }
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if let url = store.channel.youtubeURL {
                        ShareLink(item: url) {
                            Label(
                                String.localised("generic.share", table: .generic),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                    }

                    Button(role: .destructive) {
                        send(.unsubscribeTapped)
                    } label: {
                        Label(String.localised("generic.unsubscribe", table: .generic), systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                }
            }
            #endif
        }
        .onAppear { send(.viewDidAppear) }
        .onChange(of: store.channel.channelId) {
            send(.viewDidAppear)
        }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            bannerView

            channelThumbView

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

    private let bannerHeight: CGFloat = 180

    private var bannerView: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .scrollView).minY
            let stretchOffset = max(minY, 0)
            let height = bannerHeight + stretchOffset

            Group {
                if let bannerURL = store.channelBannerURL {
                    AsyncImage(url: bannerURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            bannerPlaceholder
                        }
                    }
                } else {
                    bannerPlaceholder
                }
            }
            .frame(width: geo.size.width, height: height)
            .clipped()
            .offset(y: -stretchOffset)
        }
        .frame(height: bannerHeight)
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(Color.Surface.highlight)
    }

    private var avatarSize: CGFloat {
        horizontalSizeClass == .regular ? 120 : 80
    }

    private var videosSectionHeader: some View {
        HStack {
            Text(String.localised("generic.videos", table: .generic))
                .font(.headline)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            VideoSortMenu(current: store.videoSortOrder) { sort in
                send(.videoSortOrderChanged(sort), animation: .default)
            }

            HStack(spacing: 8) {
                filterPill(String(localized: "All"), filter: .all)
                filterPill(String(localized: "Unwatched"), filter: .unwatched)
                clearButton
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var clearButton: some View {
        Button {
            send(.clearFilteredTapped)
        } label: {
            Text(String.localised("video.clear", table: .videos))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.filteredVideos.isEmpty)
        .opacity(store.filteredVideos.isEmpty ? 0.4 : 1.0)
    }

    private func filterPill(_ title: String, filter: ChannelVideoFilter) -> some View {
        let isSelected = store.videoFilter == filter
        return Button {
            send(.videoFilterChanged(filter), animation: .default)
        } label: {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : Color.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.Accent.dark : Color.Surface.highlight)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var downloadsSectionHeader: some View {
        HStack {
            Text(String.localised("video.pendingDownloads", table: .videos))
                .font(.headline)
                .foregroundStyle(Color.Text.primary)

            Spacer()

            Button {
                send(.downloadSortToggled, animation: .default)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption2)
                    Text(store.showNewestDownloadsFirst
                         ? String.localised("generic.recentlyAdded", table: .generic)
                         : String.localised("generic.oldestAdded", table: .generic))
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.Surface.highlight)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var channelThumbView: some View {
        ChannelThumbView(url: store.channelThumbURL, size: avatarSize)
            .overlay(Circle().stroke(Color.Brand.primary, lineWidth: 3))
            .offset(y: -(avatarSize / 2))
            .padding(.bottom, -(avatarSize / 2))
    }

    private var videoCardWidth: CGFloat {
        horizontalSizeClass == .regular ? 300 : 260
    }

    private var videosContent: some View {
        VStack(spacing: 12) {
            if store.isLoadingVideos && store.videos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(VideoResponse.placeholders.prefix(4)) { video in
                            VideoCardView(
                                video: video,
                                serverConfig: store.serverConfig
                            )
                            .frame(width: videoCardWidth)
                            .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.vertical, 8)
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .contentMargins(.horizontal, 16)
                .scrollTargetBehavior(.viewAligned)
            } else if store.filteredVideos.isEmpty && store.hasLoadedVideos {
                VideoCardView(
                    video: .placeholder,
                    serverConfig: store.serverConfig
                )
                .frame(width: videoCardWidth)
                .hidden()
                .overlay {
                    Text(store.videoFilter == .unwatched
                         ? String(localized: "No unwatched videos")
                         : String.localised("video.empty.noVideos", table: .videos))
                        .font(.subheadline)
                        .foregroundStyle(Color.Brand.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(store.filteredVideos) { video in
                            VideoCardView(
                                video: video,
                                serverConfig: store.serverConfig
                            )
                            .frame(width: videoCardWidth)
                            #if !os(tvOS)
                            .contextMenu {
                                VideoContextMenu(
                                    youtubeURL: video.youtubeURL,
                                    onPlayNext: { send(.playNextTapped(video), animation: .default) },
                                    onAddToPlaylist: {},
                                    onDownloadToDevice: { send(.downloadToDeviceTapped(video)) },
                                    onMarkAsWatched: { send(.markAsWatchedTapped(video)) },
                                    onDeleteFromServer: { send(.deleteFromServerTapped(video)) }
                                )
                            }
                            #endif
                            .pressable {
                                send(.videoCardTapped(video))
                            }
                            .onAppear {
                                if video.id == store.videos.last?.id {
                                    send(.lastVideoAppeared)
                                }
                            }
                        }

                        if store.isLoadingMoreVideos {
                            ProgressView()
                                .tint(Color.Progress.tint)
                                .frame(width: 60)
                        }
                    }
                    .padding(.vertical, 8)
                    .scrollTargetLayout()
                }
                .scrollClipDisabled()
                .contentMargins(.horizontal, 16)
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(.bottom, 8)
    }

    private var pendingDownloadsContent: some View {
        VStack(spacing: 0) {
            if store.isLoadingDownloads {
                ForEach(DownloadResponse.placeholders) { download in
                    pendingRow(download)
                        .redacted(reason: .placeholder)
                }
            } else {
                ForEach(store.pendingDownloads) { download in
                    DownloadRowWithPopover(
                        download: download,
                        store: store
                    )
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func pendingRow(_ download: DownloadResponse) -> some View {
        VideoRowView(
            title: download.title ?? "",
            subtitle: download.publishedRelative,
            thumbnailURL: download.thumbURL(config: store.serverConfig)
        )
    }

}
#endif
