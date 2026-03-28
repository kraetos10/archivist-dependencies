#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

public struct iPadTabScreen: View {
    @Bindable public var store: StoreOf<TabReducer>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectTab)) {
            Tab(String.localised("generic.home", table: .generic), systemImage: "house", value: AppTab.home) {
                iPadVideoListScreen(store: store.scope(state: \.videoList, action: \.videoList))
            }

            Tab(
                String.localised("generic.channels", table: .generic),
                systemImage: "antenna.radiowaves.left.and.right",
                value: AppTab.channels
            ) {
                iPadChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
            }

            Tab(
                String.localised("generic.playlists", table: .generic),
                systemImage: "music.note.list",
                value: AppTab.playlists
            ) {
                iPadPlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
            }

            Tab(
                String.localised("generic.settings", table: .generic),
                systemImage: "gearshape",
                value: AppTab.settings
            ) {
                SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
            }
            .badge(store.activeDownload != nil ? 1 : 0)
        }
        .tabViewStyle(.sidebarAdaptable)
        .overlay(alignment: .bottomLeading) {
            if let mini = store.miniPlayer {
                MiniPlayerView(
                    title: mini.video.title,
                    channelName: mini.video.channelName,
                    thumbUrl: mini.video.vidThumbUrl,
                    serverConfig: mini.serverConfig,
                    isPlaying: PlayerManager.shared.isPlaying,
                    isInPiP: PlayerManager.shared.isInPiP,
                    onTap: { store.send(.miniPlayerTapped) },
                    onPlayPause: { store.send(.miniPlayerPlayPauseTapped) },
                    onClose: { store.send(.miniPlayerCloseTapped) }
                )
                .padding(.leading, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: store.miniPlayer != nil)
        .tint(Color.Accent.dark)
        .onAppear { store.send(.appeared) }
        .onChange(of: scenePhase) {
            store.send(.scenePhaseChanged(scenePhase))
        }
    }
}
#endif
