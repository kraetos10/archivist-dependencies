import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

@ViewAction(for: StatsReducer.self)
public struct StatsScreen: View {
    public let store: StoreOf<StatsReducer>

    public init(store: StoreOf<StatsReducer>) {
        self.store = store
    }

    public var body: some View {
        Group {
            #if os(tvOS)
            // List on tvOS only scrolls when there's something focusable
            // for the focus engine to drive against. Stats rows are
            // read-only, so the screen got stuck and the lower sections
            // were unreachable. ScrollView + LazyVStack scrolls cleanly
            // via the remote's touch surface.
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    sections
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            #else
            List {
                sections
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            #endif
        }
        .background(Color.Brand.primary.ignoresSafeArea())
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(String.localised("settings.stats", table: .settings))
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { send(.viewDidAppear) }
    }

    @ViewBuilder
    private var sections: some View {
        if let video = store.videoStats {
            StatsOverviewSection(video: video)
            StatsVideoTypeSection(video: video)
        } else if !store.loadedSections.contains(.video) {
            StatsPlaceholderOverviewSection()
        }

        if store.channelStats != nil || store.playlistStats != nil || store.downloadStats != nil {
            StatsApplicationSection(
                channelStats: store.channelStats,
                playlistStats: store.playlistStats,
                downloadStats: store.downloadStats
            )
        } else if !store.loadedSections.contains(.channel) {
            StatsPlaceholderApplicationSection()
        }

        if let watch = store.watchStats {
            StatsWatchSection(watch: watch)
        }

        if !store.downloadHistory.isEmpty {
            StatsDownloadHistorySection(
                history: store.downloadHistory,
                isExpanded: store.isDownloadHistoryExpanded,
                onToggle: { send(.downloadHistoryToggleTapped) }
            )
        }

        if !store.biggestChannels.isEmpty {
            StatsBiggestChannelsSection(
                channels: store.biggestChannels,
                serverConfig: store.serverConfig
            )
        }
    }
}
