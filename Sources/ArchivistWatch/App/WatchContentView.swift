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
        if appState.isLoading {
            ProgressView()
        } else if let config = appState.serverConfig {
            TabView {
                WatchNowPlayingTab()
                .tabItem {
                    Label(String(localized: "tab.nowPlaying", bundle: Bundle.module), systemImage: "waveform")
                }

                WatchDownloadsView(
                    viewModel: WatchDownloadsViewModel(),
                    config: config
                )
                .tabItem {
                    Label(
                        String(localized: "tab.downloads", bundle: Bundle.module),
                        systemImage: "arrow.down.circle.fill"
                    )
                }

                WatchVideoListView(
                    viewModel: WatchVideoListViewModel(config: config)
                )
                .tabItem {
                    Label(String(localized: "tab.videos", bundle: Bundle.module), systemImage: "play.rectangle.fill")
                }

                WatchChannelsListView(
                    viewModel: WatchChannelsViewModel(config: config),
                    appState: appState
                )
                .tabItem {
                    Label(String(localized: "tab.channels", bundle: Bundle.module), systemImage: "person.2")
                }

                WatchPlaylistsListView(
                    viewModel: WatchPlaylistsViewModel(config: config),
                    appState: appState
                )
                .tabItem {
                    Label(String(localized: "tab.playlists", bundle: Bundle.module), systemImage: "music.note.list")
                }

                WatchServerQueueView(
                    viewModel: WatchServerQueueViewModel(config: config)
                )
                .tabItem {
                    Label(String(localized: "tab.queue", bundle: Bundle.module), systemImage: "arrow.down.to.line")
                }
            }
        .onChange(of: scenePhase) {
                if scenePhase == .active {
                    appState.loadServerConfig()
                }
            }
        } else {
            WatchSetupRequiredView()
                .onChange(of: scenePhase) {
                    if scenePhase == .active {
                        appState.loadServerConfig()
                    }
                }
        }
    }
}
#endif
