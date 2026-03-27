#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import Dependencies
internal import SQLiteData
import StructuredQueries
import SwiftUI

@ViewAction(for: VideoDetailReducer.self)
public struct iPhoneVideoDetailScreen: View {
    @Bindable public var store: StoreOf<VideoDetailReducer>

    public init(store: StoreOf<VideoDetailReducer>) {
        self.store = store
    }
    @State private var showAllComments = false
    @State private var currentCommentIndex: Int = 0

    public var body: some View {
        GeometryReader { geo in
            let thumbnailHeight = geo.size.width * 9 / 16

            VStack(spacing: 0) {
                playerOrThumbnail(height: thumbnailHeight)

                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            contentView
                                .padding(.top, 8)

                            if !store.comments.isEmpty || store.isLoadingComments {
                                commentsSection
                                    .padding(.vertical, 8)
                            }

                            if store.showPlayNext {
                                playNextSection
                                    .padding(.vertical, 8)
                            }

                            if !store.nextVideos.isEmpty {
                                nextUpSection
                                    .padding(.vertical, 8)
                            }

                            similarSection
                                .padding(.vertical, 16)
                        }
                        .id("scrollTop")
                    }
                    .onChange(of: store.video.videoId) {
                        showAllComments = false
                        currentCommentIndex = 0
                        scrollProxy.scrollTo("scrollTop", anchor: .top)
                    }
                }
            }
        }
            .background(Color.Brand.primary)
        .toolbar(.hidden, for: .bottomBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    send(.dismissTapped)
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.Text.primary)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { send(.viewDidAppear) }
        .sheet(isPresented: $showAllComments) {
            allCommentsSheet
        }
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.playlistPicker, action: \.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
    }

    private var allCommentsSheet: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(store.comments, id: \.commentId) { comment in
                        commentRow(comment)
                    }
                }
                .padding(16)
            }
            .background(Color.Brand.primary)
            .navigationTitle(String(localized: "Comments"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAllComments = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.Brand.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Content

    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.video.title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(2)

            metadataLine

            videoInfoRow

            if let description = store.video.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(store.isDescriptionExpanded ? nil : 5)
                    .padding(.top, 4)

                Button {
                    send(.toggleDescription, animation: .default)
                } label: {
                    Text(store.isDescriptionExpanded ? String(localized: "Show Less") : String(localized: "Show More"))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Accent.dark)
                }
            }

            actionButtonsRow
        }
        .padding(16)
    }

    private var videoInfoRow: some View {
        let items = [
            store.video.resolution,
            store.video.formattedFileSize,
            store.video.videoCodec,
            store.video.audioCodec,
        ].compactMap { $0 }

        return Group {
            if !items.isEmpty {
                HStack(spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.Text.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.Surface.highlight)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private var metadataLine: some View {
        HStack(spacing: 4) {
            Text(store.video.channelName)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)

            if let views = store.video.formattedViewCount {
                Text("·")
                Text("\(views) views")
            }

            if let published = store.video.publishedRelative {
                Text("·")
                Text(published)
            }
        }
        .font(.subheadline)
        .foregroundStyle(Color.Brand.secondary)
        .lineLimit(1)
    }

    private var actionButtonsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let likes = store.video.formattedLikeCount {
                    actionPill(systemImage: "hand.thumbsup", label: likes)
                }

                if let dislikes = store.video.formattedDislikeCount {
                    actionPill(systemImage: "hand.thumbsdown", label: dislikes)
                }

                Button {
                    HapticFeedback.selection.play()
                    send(.toggleWatchedTapped)
                } label: {
                    actionPillLabel(
                        systemImage: store.isWatched ? "eye.fill" : "eye",
                        label: store.isWatched
                            ? String(localized: "Watched")
                            : String(localized: "Unwatched")
                    )
                }

                if store.showPlayNext && !playNextItems.contains(where: { $0.videoId == store.video.videoId }) {
                    Button {
                        send(.addToPlayNextTapped)
                    } label: {
                        actionPillLabel(systemImage: "text.line.last.and.arrowtriangle.forward", label: String(localized: "Play Next"))
                    }
                }

                Button {
                    HapticFeedback.selection.play()
                    send(.addToPlaylistTapped)
                } label: {
                    actionPillLabel(systemImage: "text.badge.plus", label: String(localized: "Add to Playlist"))
                }

                ShareLink(item: store.youtubeURL) {
                    actionPillLabel(systemImage: "arrowshape.turn.up.right", label: String(localized: "Share"))
                }

                downloadPill
            }
        }
    }

    private func actionPill(systemImage: String, label: String) -> some View {
        actionPillLabel(systemImage: systemImage, label: label)
    }

    private func actionPillLabel(systemImage: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline)
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundStyle(Color.Text.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.Surface.highlight)
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var downloadPill: some View {
        if store.isDownloading {
            HStack(spacing: 6) {
                ZStack {
                    Circle()
                        .stroke(Color.Brand.secondary.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                    Circle()
                        .trim(from: 0, to: store.downloadProgress)
                        .stroke(Color.Accent.dark, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 18, height: 18)
                        .rotationEffect(.degrees(-90))
                }
                Text(String(localized: "Download to Device"))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.Text.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.Surface.highlight)
            .clipShape(Capsule())
        } else {
            Menu {
                if store.isDownloaded {
                    Button(role: .destructive) {
                        HapticFeedback.warning.play()
                        send(.deleteDownloadTapped)
                    } label: {
                        Label(String(localized: "Delete Download"), systemImage: "internaldrive")
                    }
                } else {
                    Button {
                        HapticFeedback.medium.play()
                        send(.downloadTapped)
                    } label: {
                        Label(String(localized: "Download to Device"), systemImage: "arrow.down.circle")
                    }
                }
                Button(role: .destructive) {
                    HapticFeedback.warning.play()
                    send(.deleteFromServerTapped)
                } label: {
                    Label(String(localized: "Delete from Server"), systemImage: "trash")
                }
            } label: {
                actionPillLabel(systemImage: "ellipsis", label: "")
            }
        }
    }

    // MARK: - Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showAllComments = true
            } label: {
                HStack {
                    Text(String(localized: "Comments"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.Text.primary)

                    if !store.comments.isEmpty {
                        Text("\(store.comments.count)")
                            .font(.subheadline)
                            .foregroundStyle(Color.Brand.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
            .buttonStyle(.plain)

            if store.isLoadingComments {
                commentCard(VideoComment.placeholder)
                    .redacted(reason: .placeholder)
            } else {
                let comments = Array(store.comments.prefix(3))
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(comments.enumerated()), id: \.element.commentId) { index, comment in
                            commentCard(comment)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: Binding(
                    get: { currentCommentIndex as Int? },
                    set: { currentCommentIndex = $0 ?? 0 }
                ))

                if comments.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<comments.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentCommentIndex
                                      ? Color.Text.primary
                                      : Color.Brand.secondary.opacity(0.5))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func commentCard(_ comment: VideoComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)

                Text(comment.commentAuthor ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)

                if let date = comment.relativeDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }

                Spacer()

                if let likes = comment.commentLikeCount, likes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption)
                        Text("\(likes)")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.Brand.secondary)
                }
            }

            Text(comment.commentText ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func commentRow(_ comment: VideoComment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.commentAuthor ?? "")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.Text.primary)

                if let date = comment.relativeDate {
                    Text(date)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }

                Spacer()

                if let likes = comment.commentLikeCount, likes > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup.fill")
                            .font(.caption)
                        Text("\(likes)")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.Brand.secondary)
                }

                if comment.commentIsFavorited == true {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Text(comment.commentText ?? "")
                .font(.subheadline)
                .foregroundStyle(Color.Text.primary)
        }
        .padding(12)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Next Up

    private var nextUpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "nextUp"))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(store.nextVideos.prefix(10), id: \.videoId) { video in
                        similarVideoRow(video)
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

    // MARK: - Play Next Queue

    @FetchAll(PlayNextItem.all.order(by: \.id))
    private var playNextItems

    private var playNextSection: some View {
        Group {
            if !playNextItems.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(String(localized: "Play Next"))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.Text.primary)
                        .padding(.horizontal, 16)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(playNextItems) { item in
                                playNextRow(item)
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

    private func playNextRow(_ item: PlayNextItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(item.title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.Text.primary)
                .lineLimit(1)

            Text(item.channelName)
                .font(.caption2)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(width: 200)
        .contextMenu {
            Button(role: .destructive) {
                send(.removeFromPlayNextTapped(item.id), animation: .default)
            } label: {
                Label(String(localized: "Remove"), systemImage: "minus.circle")
            }
        }
    }

    // MARK: - Similar Videos

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Similar Videos"))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color.Text.primary)
                .padding(.horizontal, 16)

            if store.isLoadingSimilar {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(VideoResponse.placeholders.prefix(4)) { video in
                            similarVideoRow(video)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .scrollClipDisabled()
            } else if store.similarVideos.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "play.rectangle.on.rectangle")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.Brand.secondary)
                    Text(String(localized: "No similar videos found"))
                        .font(.subheadline)
                        .foregroundStyle(Color.Brand.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(store.similarVideos) { video in
                            similarVideoRow(video)
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

    private func similarVideoRow(_ video: VideoResponse) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
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
                } else {
                    Rectangle()
                        .fill(Color.Brand.secondary.opacity(0.3))
                        .aspectRatio(16 / 9, contentMode: .fill)
                }

                if video.watchProgress > 0 {
                    VStack {
                        Spacer()
                        WatchProgressBar(progress: video.watchProgress, height: 3)
                    }
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(1)

                Text(video.channelName)
                    .font(.caption2)
                    .foregroundStyle(Color.Brand.secondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let duration = video.durationStr {
                        Text(duration)
                    }

                    if let views = video.formattedViewCount {
                        Text("· \(views) views")
                    }
                }
                .font(.caption2)
                .foregroundStyle(Color.Brand.secondary)
                .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 180)
        .background(Color.Surface.highlight)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    // MARK: - Player / Thumbnail

    @ViewBuilder
    private func playerOrThumbnail(height: CGFloat) -> some View {
        if store.isPlaying {
            ZStack {
                AVPlayerViewControllerWrapper()
                    .frame(height: height)
                    .frame(maxWidth: .infinity)

                if PlayerManager.shared.isBuffering {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }
            }
            .frame(height: height)
        } else {
            thumbnailView(height: height)
        }
    }

    private func thumbnailView(height: CGFloat) -> some View {
        ZStack {
            if let thumbURL = thumbnailURL {
                AsyncImage(url: thumbURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: height)
                            .clipped()
                    default:
                        thumbnailPlaceholder(height: height)
                    }
                }
            } else {
                thumbnailPlaceholder(height: height)
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.9))
                .shadow(radius: 8)
        }
        .frame(height: height)
        .overlay(alignment: .bottom) {
            if store.video.watchProgress > 0 {
                WatchProgressBar(progress: store.video.watchProgress, height: 5)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HapticFeedback.light.play()
            send(.playTapped)
        }
    }

    private func thumbnailPlaceholder(height: CGFloat) -> some View {
        Rectangle()
            .fill(Color.Brand.secondary.opacity(0.3))
            .frame(height: height)
    }

    private var thumbnailURL: URL? {
        guard let thumbPath = store.video.vidThumbUrl else { return nil }
        return store.serverConfig.fullURL(for: thumbPath)
    }
}

#endif
