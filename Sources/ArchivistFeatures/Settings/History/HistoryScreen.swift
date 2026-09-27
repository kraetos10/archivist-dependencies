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

    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        ScrollView {
            #if os(tvOS)
            // tvOS settings sub-screens title themselves in the content
            // (the navigation bar title is blanked under the tab bar).
            Text(String.localised("settings.history", table: .settings))
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, TVLayout.rowVerticalPadding)
            #endif

            if store.showsEmptyState {
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
            if store.showsPlaceholders {
                ForEach(VideoResponse.placeholders) { video in
                    HistoryRowView(row: HistoryRow(video: video, config: store.serverConfig))
                        .redacted(reason: .placeholder)
                }
            } else {
                let continueRows = store.continueRows
                if !continueRows.isEmpty {
                    sectionHeader(String.localised("video.continueWatching", table: .videos))
                    ForEach(continueRows) { row in
                        HistoryRowView(row: row)
                            .pressable { send(.videoTapped(row.video)) }
                    }
                }

                let watchedRows = store.watchedRows
                if !watchedRows.isEmpty {
                    sectionHeader(String.localised("video.watched", table: .videos))
                    ForEach(watchedRows) { row in
                        HistoryRowView(row: row)
                            .pressable { send(.videoTapped(row.video)) }
                            .onAppear { send(.itemAppeared(row.id)) }
                    }
                }
            }
        }
    }

    // MARK: - iPad Layout (grid cards)

    private var iPadContent: some View {
        let columns = [GridItem(.adaptive(minimum: 300), spacing: 16)]
        return LazyVGrid(columns: columns, spacing: 16) {
            if store.showsPlaceholders {
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
                                .onAppear { send(.itemAppeared(video.id)) }
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
        LazyVGrid(columns: TVLayout.cardGridColumns, spacing: TVLayout.cardSpacing) {
            if store.showsPlaceholders {
                ForEach(VideoResponse.placeholders) { video in
                    TVVideoCardView(video: video, serverConfig: store.serverConfig)
                        .redacted(reason: .placeholder)
                        .disabled(true)
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
                            .onAppear { send(.itemAppeared(video.id)) }
                        }
                    } header: {
                        sectionHeader(String.localised("video.watched", table: .videos))
                    }
                }
            }
        }
        .padding(.bottom, TVLayout.rowVerticalPadding)
    }
    #endif

    // MARK: - Shared

    private func sectionHeader(_ title: String) -> some View {
        #if os(tvOS)
        // The tvOS section header convention shared with the other screens.
        Text(title)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(Color.Text.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, TVLayout.sectionHeaderSpacing)
            .padding(.bottom, TVLayout.sectionHeaderSpacing)
        #else
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 4)
        #endif
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(Color.Brand.secondary)
            Text(String.localised("settings.noHistory", table: .settings))
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

#if !os(tvOS)
private struct HistoryRowView: View {
    let row: HistoryRow

    var body: some View {
        VideoRowView(
            title: row.video.title,
            subtitle: row.video.channelName,
            secondarySubtitle: row.viewCountText,
            thumbnailURL: row.thumbnailURL,
            badge: row.video.durationStr,
            thumbnailWidth: 160
        )
    }
}
#endif
