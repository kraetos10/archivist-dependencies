#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

public struct TabScreen: View {
    @Bindable public var store: StoreOf<TabReducer>

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        if sizeClass == .regular {
            iPadTabScreen(store: store)
        } else {
            iPhoneTabScreen
        }
    }

    private var iPhoneTabScreen: some View {
        TabView(selection: $store.selectedTab.sending(\.selectTab)) {
            VideoListScreen(store: store.scope(state: \.videoList, action: \.videoList))
                .tabItem {
                    Label(String.localised("generic.home"), systemImage: "house")
                }
                .tag(AppTab.home)

            ChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
                .tabItem {
                    Label(String.localised("generic.channels"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(AppTab.channels)

            PlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
                .tabItem {
                    Label(String.localised("generic.playlists"), systemImage: "music.note.list")
                }
                .tag(AppTab.playlists)

            SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label(String.localised("generic.settings"), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
                .badge(store.activeDownload != nil ? 1 : 0)
        }
        .safeAreaInset(edge: .bottom) {
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
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.default, value: store.miniPlayer != nil)
        .tint(Color.Accent.dark)
        .onAppear { store.send(.appeared) }
    }
}
#endif
