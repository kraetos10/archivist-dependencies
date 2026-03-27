import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: HistoryReducer.self)
public struct HistoryScreen: View {
    public let store: StoreOf<HistoryReducer>

    public init(store: StoreOf<HistoryReducer>) {
        self.store = store
    }

    #if os(tvOS)
    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 48)]
    #endif

    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        ScrollView {
            if store.hasLoaded && store.continueVideos.isEmpty && store.watchedVideos.isEmpty {
                emptyState
            } else {
                #if os(tvOS)
                tvContent
                #else
                if sizeClass == .regular {
                    iPadContent
                } else {
                    iPhoneContent
                }
                #endif

                if store.isLoadingMore {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .padding()
                }
            }
        }
        .background(Color.Brand.primary.ignoresSafeArea())
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(String.localised("settings.history", table: .settings))
        #endif
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { send(.viewDidAppear) }
    }

    // MARK: - iPhone Layout (horizontal rows)

    #if !os(tvOS)
    private var iPhoneContent: some View {
        LazyVStack(spacing: 0) {
            if store.isLoading && !store.hasLoaded {
                ForEach(VideoResponse.placeholders) { video in
                    historyRow(video)
                        .redacted(reason: .placeholder)
                }
            } else {
                if !store.continueVideos.isEmpty {
                    sectionHeader(String.localised("video.continueWatching", table: .videos))
                    ForEach(store.continueVideos) { video in
                        historyRow(video)
                            .pressable { send(.videoTapped(video)) }
                    }
                }

                if !store.watchedVideos.isEmpty {
                    sectionHeader(String.localised("video.watched", table: .videos))
                    ForEach(store.watchedVideos) { video in
                        historyRow(video)
                            .pressable { send(.videoTapped(video)) }
                            .onAppear {
                                if video.id == store.watchedVideos.last?.id {
                                    send(.lastItemAppeared)
                                }
                            }
                    }
                }
            }
        }
    }

    private func historyRow(_ video: VideoResponse) -> some View {
        HStack(alignment: .top, spacing: 12) {
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

                if let durationStr = video.durationStr {
                    Text(durationStr)
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
            .frame(width: 160)
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(3)

                Text(video.channelName)
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)

                if let views = video.formattedViewCount {
                    Text("\(views) views")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - iPad Layout (grid cards)

    private var iPadContent: some View {
        let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            if store.isLoading && !store.hasLoaded {
                ForEach(VideoResponse.placeholders) { video in
                    VideoCardView(video: video, serverConfig: store.serverConfig)
                        .redacted(reason: .placeholder)
                }
            } else {
                if !store.continueVideos.isEmpty {
                    Section {
                        ForEach(store.continueVideos) { video in
                            VideoCardView(video: video, serverConfig: store.serverConfig)
                                .pressable { send(.videoTapped(video)) }
                        }
                    } header: {
                        sectionHeader(String.localised("video.continueWatching", table: .videos))
                    }
                }

                if !store.watchedVideos.isEmpty {
                    Section {
                        ForEach(store.watchedVideos) { video in
                            VideoCardView(video: video, serverConfig: store.serverConfig)
                                .pressable { send(.videoTapped(video)) }
                                .onAppear {
                                    if video.id == store.watchedVideos.last?.id {
                                        send(.lastItemAppeared)
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(String.localised("video.watched", table: .videos))
                    }
                }
            }
        }
        .padding()
    }
    #endif

    // MARK: - tvOS Layout

    #if os(tvOS)
    private var tvContent: some View {
        LazyVGrid(columns: columns, spacing: 48) {
            if store.isLoading && !store.hasLoaded {
                ForEach(VideoResponse.placeholders) { video in
                    TVVideoCardView(video: video, serverConfig: store.serverConfig)
                        .redacted(reason: .placeholder)
                }
            } else {
                if !store.continueVideos.isEmpty {
                    Section {
                        ForEach(store.continueVideos) { video in
                            TVVideoCardView(video: video, serverConfig: store.serverConfig) {
                                send(.videoTapped(video))
                            }
                        }
                    } header: {
                        sectionHeader(String.localised("video.continueWatching", table: .videos))
                    }
                }

                if !store.watchedVideos.isEmpty {
                    Section {
                        ForEach(store.watchedVideos) { video in
                            TVVideoCardView(video: video, serverConfig: store.serverConfig) {
                                send(.videoTapped(video))
                            }
                            .onAppear {
                                if video.id == store.watchedVideos.last?.id {
                                    send(.lastItemAppeared)
                                }
                            }
                        }
                    } header: {
                        sectionHeader(String.localised("video.watched", table: .videos))
                    }
                }
            }
        }
        .padding(48)
    }
    #endif

    // MARK: - Shared

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(Color.Brand.secondary)
            Text(String.localised("settings.noHistory", table: .settings))
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}
