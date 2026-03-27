#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelDetailReducer.self)
public struct TVChannelDetailScreen: View {
    @Bindable public var store: StoreOf<ChannelDetailReducer>

    public init(store: StoreOf<ChannelDetailReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 48)]


    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                headerView
                    .focusSection()

                Section {
                    videosContent
                } header: {
                    PinnedSectionHeader(title: String(localized: "Videos"))
                }
                .focusSection()

                if !store.pendingDownloads.isEmpty || store.isLoadingDownloads {
                    Section {
                        pendingDownloadsContent
                    } header: {
                        PinnedSectionHeader(title: String(localized: "Pending Downloads"))
                    }
                    .focusSection()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            bannerView

            channelThumbView

            Text(store.channel.channelName)
                .font(.title2)
                .fontWeight(.bold)

            if let subs = store.channel.formattedSubs {
                Text("\(subs) subscribers")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            if let description = store.channel.channelDescription, !description.isEmpty {
                VStack(spacing: 8) {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(store.isDescriptionExpanded ? nil : 5)
                        .multilineTextAlignment(.center)

                    Button {
                        send(.descriptionToggleTapped, animation: .default)
                    } label: {
                        Text(store.isDescriptionExpanded ? String(localized: "Show Less") : String(localized: "Show More"))
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 80)
            }
        }
        .padding(.bottom, 32)
    }

    private let bannerHeight: CGFloat = 300

    private var bannerView: some View {
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
        .frame(height: bannerHeight)
        .clipped()
    }

    private var bannerPlaceholder: some View {
        Rectangle()
            .fill(.secondary.opacity(0.2))
            .frame(height: bannerHeight)
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
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .offset(y: -60)
        .padding(.bottom, -60)
    }

    private var thumbPlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.3))
    }

    // MARK: - Sections

    private var videosContent: some View {
        Group {
            if store.isLoadingVideos && store.videos.isEmpty {
                LazyVGrid(columns: columns, spacing: 48) {
                    ForEach(VideoResponse.placeholders) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        )
                        .redacted(reason: .placeholder)
                    }
                }
                .padding(.horizontal, 48)
            } else if store.videos.isEmpty && store.hasLoadedVideos {
                Text(String(localized: "No videos yet"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .focusable()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                LazyVGrid(columns: columns, spacing: 48) {
                    ForEach(store.videos) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        ) {
                            send(.videoCardTapped(video))
                        }
                        .onAppear {
                            if video.id == store.videos.last?.id {
                                send(.lastVideoAppeared)
                            }
                        }
                    }
                }
                .padding(.horizontal, 48)

                if store.isLoadingMoreVideos {
                    ProgressView()
                        .padding()
                }
            }
        }
        .padding(.bottom, 48)
    }

    private var pendingDownloadsContent: some View {
        LazyVGrid(columns: columns, spacing: 48) {
            if store.isLoadingDownloads {
                ForEach(DownloadResponse.placeholders) { download in
                    TVVideoCardView(
                        download: download,
                        serverConfig: store.serverConfig
                    )
                    .redacted(reason: .placeholder)
                }
            } else {
                ForEach(store.pendingDownloads) { download in
                    TVVideoCardView(
                        download: download,
                        serverConfig: store.serverConfig
                    ) {
                        send(.downloadCardTapped(download))
                    }
                }
            }
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 48)
    }
}
#endif
