#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelDetailReducer.self)
public struct TVChannelDetailScreen: View {
    @Bindable public var store: StoreOf<ChannelDetailReducer>

    /// The header's one focus target. Focusing it scrolls the whole header
    /// (banner included) back into view — the focus engine alone would only
    /// scroll far enough to reveal the target itself.
    @FocusState private var isHeaderFocused: Bool

    public init(store: StoreOf<ChannelDetailReducer>) {
        self.store = store
    }

    private static let headerID = "channelHeader"

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    headerView
                        .id(Self.headerID)
                        .focusSection()

                    Section {
                        videosContent
                    } header: {
                        videosSectionHeader
                            .focusSection()
                    }

                    if !store.pendingDownloads.isEmpty || store.isLoadingDownloads {
                        Section {
                            pendingDownloadsContent
                        } header: {
                            downloadsSectionHeader
                                .focusSection()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .onChange(of: isHeaderFocused) { _, isFocused in
                guard isFocused else { return }
                withAnimation { proxy.scrollTo(Self.headerID, anchor: .top) }
            }
        }
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(isPresented: $store.isDescriptionExpanded) {
            TVFullDescriptionView(
                title: store.channel.channelName,
                blocks: store.descriptionBlocks
            )
        }
    }

    // MARK: - Videos Header

    private var videosSectionHeader: some View {
        HStack {
            Text(String.localised("generic.videos", table: .generic))
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            HStack(spacing: 12) {
                ForEach(VideoSortOrder.allCases, id: \.self) { sort in
                    let isSelected = store.videoSortOrder == sort
                    Button {
                        send(.videoSortOrderChanged(sort))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: sort.icon)
                                .accessibilityHidden(true)
                            Text(sort.label)
                        }
                    }
                    .buttonStyle(TVCapsuleButtonStyle(isSelected: isSelected))
                }
            }
        }
        .padding(.vertical, TVLayout.sectionHeaderSpacing)
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 16) {
            TVDetailBannerView(url: store.channelBannerURL)

            channelThumbView

            if store.descriptionBlocks.isEmpty {
                // Nothing to open, but the header still needs a focus
                // target or it can never be scrolled back into view.
                channelInfoView
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: TVLayout.cornerRadius)
                            .fill(Color.Surface.highlight.opacity(isHeaderFocused ? 1 : 0))
                    )
                    .focusable()
                    .focused($isHeaderFocused)
                    .animation(.easeInOut(duration: 0.15), value: isHeaderFocused)
            } else {
                channelInfoView

                TVDescriptionCard(text: store.channel.channelDescription ?? "") {
                    send(.descriptionToggleTapped)
                }
                .focused($isHeaderFocused)
                .padding(.top, 8)
            }
        }
        .padding(.top, TVLayout.rowVerticalPadding)
        .padding(.bottom, 32)
    }

    private var channelInfoView: some View {
        VStack(spacing: 8) {
            Text(store.channel.channelName)
                .font(.title2)
                .fontWeight(.bold)

            if let subs = store.channel.formattedSubs {
                Text(String.localised("\(subs) subscribers"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var channelThumbView: some View {
        ChannelThumbView(url: store.channelThumbURL, size: 120)
            .offset(y: -60)
            .padding(.bottom, -60)
    }

    // MARK: - Downloads Header

    private var downloadsSectionHeader: some View {
        HStack {
            Text(String.localised("video.pendingDownloads", table: .videos))
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            Button {
                send(.downloadSortToggled)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.arrow.down")
                        .accessibilityHidden(true)
                    Text(
                        store.showNewestDownloadsFirst
                            ? String.localised("generic.descending", table: .generic)
                            : String.localised("generic.ascending", table: .generic)
                    )
                }
            }
            .buttonStyle(TVCapsuleButtonStyle())
        }
        .padding(.vertical, TVLayout.sectionHeaderSpacing)
    }

    // MARK: - Sections

    private var videosContent: some View {
        Group {
            if store.isLoadingVideos && store.videos.isEmpty {
                LazyVGrid(columns: TVLayout.cardGridColumns, spacing: TVLayout.cardSpacing) {
                    ForEach(VideoResponse.placeholders) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        )
                        .redacted(reason: .placeholder)
                        .disabled(true)
                    }
                }
                .focusSection()
            } else if store.videos.isEmpty && store.hasLoadedVideos {
                Text(String.localised("video.empty.noVideos", table: .videos))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .focusable()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
            } else {
                LazyVGrid(columns: TVLayout.cardGridColumns, spacing: TVLayout.cardSpacing) {
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
                .focusSection()

                if store.isLoadingMoreVideos {
                    ProgressView()
                        .padding()
                }
            }
        }
        .padding(.bottom, 48)
    }

    private var pendingDownloadsContent: some View {
        LazyVGrid(columns: TVLayout.cardGridColumns, spacing: TVLayout.cardSpacing) {
            if store.isLoadingDownloads {
                ForEach(DownloadResponse.placeholders) { download in
                    TVVideoCardView(
                        download: download,
                        serverConfig: store.serverConfig
                    )
                    .redacted(reason: .placeholder)
                    .disabled(true)
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
        .focusSection()
        .padding(.bottom, 48)
    }
}
#endif
