#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Dependencies
internal import SQLiteData
import StructuredQueries
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct TVVideoDetailScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>

    /// The control focus returns to whenever this screen's content changes
    /// underneath the user. Without an explicit target the focus engine
    /// guesses — see `body`.
    @FocusState private var focusedControl: FocusedControl?

    private enum FocusedControl: Hashable {
        case play
    }

    /// Scroll anchor for the top of the screen.
    private static let topAnchor = "top"

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }

    public var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    hero
                        .id(Self.topAnchor)

                    playNextSection
                    upNextSection
                    similarSection
                    commentsSection
                }
            }
            .scrollIndicators(.hidden)
            // Land on Play when the screen first appears, rather than wherever
            // the focus engine's reading-order guess happens to put it.
            .defaultFocus($focusedControl, .play)
            // Picking a Similar, Up Next or Play Next video — or auto-advance —
            // swaps this screen's video in place rather than pushing a new
            // screen. The card that had focus is gone, its row reloading, and the
            // scroll was left wherever that row sat, so focus fell to whatever
            // the engine found. Start the new video's screen the way the first
            // one started: at the top, on Play.
            .onChange(of: store.video.videoId) {
                withAnimation {
                    scrollProxy.scrollTo(Self.topAnchor, anchor: .top)
                }
                focusedControl = .play
            }
            // Back from the player (Menu), put focus on Play/Resume. Auto-advance
            // may have changed the video while the player was up, so the control
            // focused before presenting isn't guaranteed to still mean anything.
            .onChange(of: store.isPlaying) { _, isPlaying in
                if !isPlaying {
                    focusedControl = .play
                }
            }
        }
        // Menu in the player dismisses this cover, which stops playback.
        .fullScreenCover(isPresented: $store.isPlaying.sending(\.view.playerPresentationChanged)) {
            TVVLCPlayerView()
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $store.isDescriptionExpanded) {
            TVFullDescriptionView(
                title: store.video.title,
                blocks: store.descriptionBlocks
            )
        }
        .fullScreenCover(item: $store.expandedComment) { comment in
            TVFullDescriptionView(
                title: comment.fullTextTitle,
                blocks: comment.fullTextBlocks
            )
        }
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(alignment: .top, spacing: 48) {
            thumbnailView
                .frame(width: 640, height: 360)

            VStack(alignment: .leading, spacing: 20) {
                Text(store.video.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(2)

                metadata

                HStack(spacing: 24) {
                    Button {
                        send(.playTapped)
                    } label: {
                        // Always Play: a partly-watched video asks
                        // resume-or-restart once pressed, so the
                        // button can't promise either.
                        Label(String.localised("video.play", table: .videos), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .focused($focusedControl, equals: .play)

                    Button {
                        send(.toggleWatchedTapped)
                    } label: {
                        Label(
                            store.isWatched
                                ? String.localised("video.markAsUnwatched", table: .videos)
                                : String.localised("video.markAsWatched", table: .videos),
                            systemImage: store.isWatched ? "eye.fill" : "eye"
                        )
                    }
                    .buttonStyle(.bordered)
                }

                if let description = store.descriptionPreview {
                    // Clamped here; the whole text opens in its own view,
                    // where it can be scrolled with the remote.
                    TVDescriptionCard(text: description) {
                        send(.toggleDescription)
                    }
                    .accessibilityLabel(String.localised("video.description", table: .videos))
                    .accessibilityValue(description)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Up/down inside the info column stays inside it rather than
            // jumping diagonally to whatever lies below the thumbnail.
            .focusSection()
        }
    }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ChannelThumbView(url: store.channelThumbURL, size: 36)
                    // Decorative: the channel name beside it says who it is.
                    .accessibilityHidden(true)

                Text(store.video.channelName)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .layoutPriority(1)

                if let details = store.viewsAndPublishedText {
                    Text("·")
                        .accessibilityHidden(true)
                    Text(details)
                        .lineLimit(1)
                }
            }

            if store.hasQualityOrDuration {
                HStack(spacing: 12) {
                    if let quality = store.video.qualityLabel {
                        Text(quality)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.Text.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.Surface.highlight)
                            .clipShape(Capsule())
                    }

                    if let duration = store.video.durationStr {
                        Text(duration)
                            .lineLimit(1)
                    }
                }
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    // MARK: - Thumbnail

    private var thumbnailView: some View {
        ZStack {
            if let thumbURL = store.heroThumbnailURL {
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

            if store.effectiveWatchProgress > 0 {
                VStack {
                    Spacer()
                    WatchProgressBar(progress: store.effectiveWatchProgress, height: 6)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TVLayout.cornerRadius))
    }

    // MARK: - Rows

    @ViewBuilder
    private var playNextSection: some View {
        if !store.playNextItems.isEmpty {
            section(String.localised("video.playNext", table: .videos)) {
                cardRow {
                    ForEach(store.playNextItems) { item in
                        TVVideoCardView(
                            playNextItem: item,
                            serverConfig: store.serverConfig
                        ) {
                            send(.playNextItemTapped(item), animation: .default)
                        }
                        .frame(width: TVLayout.cardWidth)
                        .contextMenu {
                            Button(role: .destructive) {
                                send(.removeFromPlayNextTapped(item.id), animation: .default)
                            } label: {
                                Label(
                                    String.localised("video.removeFromPlayNext", table: .videos),
                                    systemImage: "minus.circle"
                                )
                            }
                        }
                        .playNextTransition()
                    }
                }
                .animation(.default, value: store.playNextItems.map(\.id))
            }
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        if !store.nextVideos.isEmpty {
            section(String.localised("video.upNext", table: .videos)) {
                cardRow {
                    ForEach(store.nextVideos.prefix(10)) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        ) {
                            send(.nextUpVideoTapped(video))
                        }
                        .frame(width: TVLayout.cardWidth)
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
                    }
                }
            }
        }
    }

    private var similarSection: some View {
        section(String.localised("video.similarVideos", table: .videos)) {
            if store.isLoadingSimilar {
                cardRow {
                    ForEach(VideoResponse.placeholders.prefix(4)) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        )
                        .frame(width: TVLayout.cardWidth)
                        .redacted(reason: .placeholder)
                        // Placeholders must not take focus.
                        .disabled(true)
                    }
                }
            } else if store.similarVideos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .scaledSystemFont(size: 32, relativeTo: .title)
                        // Decorative: the adjacent label carries the meaning.
                        .accessibilityHidden(true)
                        .foregroundStyle(.secondary)
                    Text(String.localised("video.empty.noSimilar", table: .videos))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            } else {
                cardRow {
                    ForEach(store.similarVideos) { video in
                        TVVideoCardView(
                            video: video,
                            serverConfig: store.serverConfig
                        ) {
                            send(.similarVideoTapped(video))
                        }
                        .frame(width: TVLayout.cardWidth)
                    }
                }
            }
        }
    }

    // MARK: - Comments

    /// Hidden once loaded if there are none — an empty "Comments" heading at
    /// the bottom of the screen says nothing useful.
    @ViewBuilder
    private var commentsSection: some View {
        if store.isLoadingComments || !store.comments.isEmpty {
            section(String.localised("generic.comments", table: .generic)) {
                cardRow {
                    if store.isLoadingComments {
                        ForEach(store.commentPlaceholders) { comment in
                            TVCommentCard(comment: comment) {}
                                .redacted(reason: .placeholder)
                                // Placeholders must not take focus.
                                .disabled(true)
                        }
                    } else {
                        ForEach(store.comments) { comment in
                            TVCommentCard(comment: comment) {
                                send(.commentTapped(comment))
                            }
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TVLayout.sectionHeaderSpacing) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            content()
        }
    }

    /// A horizontal row of cards: room above and below for the focus lift,
    /// unclipped so lifted cards can overhang, and its own focus section so
    /// up/down lands in the row rather than diagonally past it.
    private func cardRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: TVLayout.cardSpacing) {
                content()
            }
            .padding(.vertical, TVLayout.rowVerticalPadding)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .focusSection()
    }
}

// MARK: - Play Next card

extension PlayNextItem {
    /// The queue row in the shape the shared card takes.
    var cardData: CardData {
        CardData(
            videoId: videoId,
            title: title,
            channelName: channelName,
            thumbPath: thumbUrl,
            duration: duration,
            publishedRelative: publishedRelative,
            isWatched: false,
            isPartiallyWatched: false,
            watchProgress: 0,
            isPending: false
        )
    }
}

extension TVVideoCardView {
    /// A Play Next queue row as the standard card, so the row matches Up
    /// Next and Similar exactly.
    init(
        playNextItem: PlayNextItem,
        serverConfig: ServerConfig,
        onTap: (() -> Void)? = nil
    ) {
        self.data = playNextItem.cardData
        self.serverConfig = serverConfig
        self.onTap = onTap
    }
}
#endif
