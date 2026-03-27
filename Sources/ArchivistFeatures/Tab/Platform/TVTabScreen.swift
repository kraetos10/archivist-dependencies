#if os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct TVTabScreen: View {
    @Bindable public var store: StoreOf<TabReducer>

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectTab)) {
            TVVideoListScreen(store: store.scope(state: \.videoList, action: \.videoList))
                .tabItem {
                    Label(String(localized: "Home"), systemImage: "house")
                }
                .tag(AppTab.home)

            TVChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
                .tabItem {
                    Label(String(localized: "Channels"), systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(AppTab.channels)

            TVPlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
                .tabItem {
                    Label(String(localized: "Playlists"), systemImage: "music.note.list")
                }
                .tag(AppTab.playlists)

            TVSettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
    }
}
#endif
