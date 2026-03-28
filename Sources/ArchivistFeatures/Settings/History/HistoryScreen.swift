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
        .refreshable { send(.pullToRefreshTriggered) }
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
        VideoRowView(
            title: video.title,
            subtitle: video.channelName,
            secondarySubtitle: video.formattedViewCount.map { "\($0) views" },
            thumbnailURL: video.vidThumbUrl.flatMap { store.serverConfig.fullURL(for: $0) },
            badge: video.durationStr,
            thumbnailWidth: 160
        )
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
