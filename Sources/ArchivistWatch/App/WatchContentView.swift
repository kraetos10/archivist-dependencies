#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchContentView: View {
    let appState: WatchAppState
    @Environment(\.scenePhase) private var scenePhase

    public init(appState: WatchAppState) {
        self.appState = appState
    }

    public var body: some View {
        Group {
            if appState.isLoading {
                ProgressView()
            } else if let tabs = appState.tabs {
                WatchTabsView(tabs: tabs)
            } else {
                WatchSetupRequiredView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appState.loadServerConfig()
            }
        }
    }
}

struct WatchTabsView: View {
    let tabs: WatchTabsModel

    var body: some View {
        TabView {
            Tab(String(localized: "tab.nowPlaying", bundle: .module), systemImage: "waveform") {
                WatchNowPlayingTab(nowPlaying: tabs.nowPlaying)
            }
            Tab(String(localized: "tab.downloads", bundle: .module), systemImage: "arrow.down.circle.fill") {
                WatchDownloadsView(viewModel: tabs.downloads)
            }
            Tab(String(localized: "tab.videos", bundle: .module), systemImage: "play.rectangle.fill") {
                WatchVideoListView(viewModel: tabs.videos)
            }
            Tab(String(localized: "tab.channels", bundle: .module), systemImage: "person.2") {
                WatchChannelsListView(viewModel: tabs.channels)
            }
            Tab(String(localized: "tab.playlists", bundle: .module), systemImage: "music.note.list") {
                WatchPlaylistsListView(viewModel: tabs.playlists)
            }
            Tab(String(localized: "tab.queue", bundle: .module), systemImage: "arrow.down.to.line") {
                WatchServerQueueView(viewModel: tabs.queue)
            }
        }
    }
}
#endif
