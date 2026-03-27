#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

public struct iPadTabScreen: View {
    @Bindable public var store: StoreOf<TabReducer>

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectTab)) {
            Tab(String.localised("generic.home"), systemImage: "house", value: AppTab.home) {
                iPadVideoListScreen(store: store.scope(state: \.videoList, action: \.videoList))
            }

            Tab(String.localised("generic.channels"), systemImage: "antenna.radiowaves.left.and.right", value: AppTab.channels) {
                iPadChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
            }

            Tab(String.localised("generic.playlists"), systemImage: "music.note.list", value: AppTab.playlists) {
                iPadPlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
            }

            Tab(String.localised("generic.settings"), systemImage: "gearshape", value: AppTab.settings) {
                SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
            }
            .badge(store.activeDownload != nil ? 1 : 0)
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(Color.Accent.dark)
        .onAppear { store.send(.appeared) }
    }
}
#endif
