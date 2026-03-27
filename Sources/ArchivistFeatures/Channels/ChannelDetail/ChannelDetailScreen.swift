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

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                headerView

                Section {
                    videosContent
                } header: {
                    PinnedSectionHeader(title: String.localised("generic.videos"))
                }

                if !store.pendingDownloads.isEmpty || store.isLoadingDownloads {
                    Section {
                        pendingDownloadsContent
                    } header: {
                        PinnedSectionHeader(title: String.localised("video.pendingDownloads", table: .videos))
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .background(Color.Brand.primary)
        .toolbar {
            #if !os(tvOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ShareLink(item: store.channel.youtubeURL) {
                        Label(String.localised("generic.share"), systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        send(.unsubscribeTapped)
                    } label: {
                        Label(String.localised("generic.unsubscribe"), systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3.weight(.semibold))
                }
            }
            #endif
        }
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }


    private var headerView: some View {
        VStack(spacing: 12) {
            bannerView

            channelThumbView

            Text(store.channel.channelName)
                .font(.title2)
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
                        Text(store.isDescriptionExpanded ? String.localised("generic.showLess") : String.localised("generic.showMore"))
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

    private var channelThumbView: some View {
        Group {
            if let thumbURL = store.channelThumbURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    default:
                        thumbPlaceholder
                    }
                }
            } else {
                thumbPlaceholder
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.Brand.primary, lineWidth: 3))
        .offset(y: -40)
        .padding(.bottom, -40)
    }

    private var thumbPlaceholder: some View {
        Circle()
            .fill(Color.Brand.secondary.opacity(0.3))
    }

    private var videosContent: some View {
        VStack(spacing: 12) {
            if store.isLoadingVideos && store.videos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(VideoResponse.placeholders.prefix(4)) { video in
                            videoCard(video)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16)
                .scrollTargetBehavior(.viewAligned)
            } else if store.videos.isEmpty && store.hasLoadedVideos {
                Text(String.localised("video.empty.noVideos", table: .videos))
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(store.videos) { video in
                            videoCard(video)
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
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16)
                .scrollTargetBehavior(.viewAligned)
            }
        }
        .padding(.bottom, 8)
    }

    private func videoCard(_ video: VideoResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if let thumbPath = video.vidThumbUrl,
                   let thumbURL = store.serverConfig.fullURL(for: thumbPath) {
                    AsyncImage(url: thumbURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16 / 9, contentMode: .fill)
                        default:
                            Rectangle()
                                .fill(Color.Brand.secondary.opacity(0.3))
                                .aspectRatio(16 / 9, contentMode: .fill)
                        }
                    }
                }

                VStack {
                    HStack {
                        if video.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                        } else if video.isPartiallyWatched {
                            Image(systemName: "circle.lefthalf.filled")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(.black.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .padding(6)
                        }
                        Spacer()
                    }

                    Spacer()

                    if video.watchProgress > 0 {
                        WatchProgressBar(progress: video.watchProgress)
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(video.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)

            if let published = video.publishedFormatted {
                Text(published)
                    .font(.caption2)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
        .frame(width: 260)
    }

    private var pendingDownloadsContent: some View {
        VStack(spacing: 12) {
            if store.isLoadingDownloads {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(DownloadResponse.placeholders) { download in
                        VideoCardView(
                            download: download,
                            serverConfig: store.serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(store.pendingDownloads) { download in
                        DownloadCardWithPopover(
                            download: download,
                            store: store
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 24)
    }

}

private struct DownloadCardWithPopover: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<ChannelDetailReducer>
    @State private var showPopover = false
    @State private var showSheet = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        VideoCardView(
            download: download,
            serverConfig: store.serverConfig
        )
        .pressable {
            store.send(.view(.downloadCardTapped(download)))
            if sizeClass == .regular {
                showPopover = true
            } else {
                showSheet = true
            }
        }
        .popover(isPresented: $showPopover) {
            if let detailStore = store.scope(state: \.downloadDetail, action: \.downloadDetail.presented) {
                DownloadDetailScreen(store: detailStore)
                    .frame(idealWidth: 420)
            }
        }
        .sheet(isPresented: $showSheet) {
            if let detailStore = store.scope(state: \.downloadDetail, action: \.downloadDetail.presented) {
                DownloadDetailScreen(store: detailStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: store.downloadDetail == nil) { _, isNil in
            if isNil {
                showPopover = false
                showSheet = false
            }
        }
    }
}
#endif
