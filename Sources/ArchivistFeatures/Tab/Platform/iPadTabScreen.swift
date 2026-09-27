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
                String.localised("video.saved", table: .videos),
                systemImage: "arrow.down.to.line",
                value: AppTab.deviceDownloads
            ) {
                NavigationStack {
                    DeviceDownloadsScreen(
                        store: store.scope(state: \.deviceDownloads, action: \.deviceDownloads)
                    )
                }
            }
            // A zero count draws nothing, so this is only visible while
            // something is actually downloading.
            .badge(store.activeDeviceDownloadCount)

            Tab(
                String.localised("generic.settings", table: .generic),
                systemImage: "gearshape",
                value: AppTab.settings
            ) {
                if store.isSettingsLocked {
                    PinLockedSettingsPlaceholder()
                } else {
                    SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                }
            }
            .badge(store.settingsBadgeCount)
        }
        .tabViewStyle(.sidebarAdaptable)
        #if os(iOS)
        .overlay {
            ExpandedMiniPlayerOverlay(store: store)
        }
        .overlay {
            MiniPlayerHostOverlay(store: store, bottomInset: 60)
        }
        #endif
        .tint(Color.Accent.dark)
        .onAppear { store.send(.appeared) }
        .sheet(item: $store.scope(state: \.settingsPin, action: \.settingsPin)) { pinStore in
            SettingsPinSheet(store: pinStore)
        }
    }
}
#endif
