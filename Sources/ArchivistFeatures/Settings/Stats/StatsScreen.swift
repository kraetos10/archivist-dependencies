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
        List {
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
        #if os(tvOS)
        .listStyle(.grouped)
        #else
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        #endif
        .background(Color.Brand.primary.ignoresSafeArea())
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(String.localised("settings.stats", table: .settings))
        #endif
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear { send(.viewDidAppear) }
    }
}
