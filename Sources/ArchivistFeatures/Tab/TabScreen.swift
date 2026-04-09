#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI
import ArchivistComponents

public struct TabScreen: View {
    @Bindable public var store: StoreOf<TabReducer>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    public var body: some View {
        if isIPad {
            iPadTabScreen(store: store)
        } else {
            iPhoneTabScreen
        }
    }

    private var iPhoneTabScreen: some View {
        TabView(selection: $store.selectedTab.sending(\.selectTab)) {
            VideoListScreen(store: store.scope(state: \.videoList, action: \.videoList))
                .tabItem {
                    Label(String.localised("generic.home", table: .generic), systemImage: "house")
                }
                .tag(AppTab.home)

            ChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
                .tabItem {
                    Label(
                        String.localised("generic.channels", table: .generic),
                        systemImage: "antenna.radiowaves.left.and.right"
                    )
                }
                .tag(AppTab.channels)

            PlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
                .tabItem {
                    Label(String.localised("generic.playlists", table: .generic), systemImage: "music.note.list")
                }
                .tag(AppTab.playlists)

            SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label(String.localised("generic.settings", table: .generic), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
                .badge(store.activeDownload != nil ? 1 : 0)
        }
        .overlay {
            ExpandedMiniPlayerOverlay(store: store)
        }
        .overlay {
            MiniPlayerHostOverlay(
                store: store,
                miniSize: CGSize(width: 200, height: 200 * 9 / 16),
                bottomInset: 60
            )
        }
        .tint(Color.Accent.dark)
        .onAppear { store.send(.appeared) }
        .onChange(of: scenePhase) {
            store.send(.scenePhaseChanged(scenePhase))
        }
    }
}

// MARK: - Expanded Mini Player Overlay

/// Shows the full `VideoDetailScreen` for the minimized video when the user
/// has tapped the mini player to expand it. Renders the SAME persistent
/// player surface that was just in the mini player — reparenting handles the
/// transfer with no playback interruption.
struct ExpandedMiniPlayerOverlay: View {
    @Bindable var store: StoreOf<TabReducer>

    var body: some View {
        if let miniStore = store.scope(
            state: \.miniPlayerDetail,
            action: \.miniPlayerDetail
        ), !store.isMiniPlayerMinimized {
            NavigationStack {
                VideoDetailScreen(store: miniStore)
            }
            .background(Color.Brand.primary)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Mini Player Host Overlay

/// Renders the mini player as a small floating view that hosts ONLY the
/// persistent player surface owned by `PlayerManager`. The full video detail
/// is never scaled — when the user expands, a new full-screen presentation
/// reparents the same persistent surface back into its player slot.
struct MiniPlayerHostOverlay: View {
    let store: StoreOf<TabReducer>
    let miniSize: CGSize
    let bottomInset: CGFloat

    var body: some View {
        if let detail = store.miniPlayerDetail, store.isMiniPlayerMinimized {
            DraggableMiniPlayerOverlay(
                miniSize: miniSize,
                bottomInset: bottomInset
            ) {
                MiniPlayerView(
                    title: detail.video.title,
                    useVLC: detail.useVLCPlayer,
                    onTap: {
                        store.send(.miniPlayerTapped)
                    },
                    onClose: {
                        store.send(.miniPlayerCloseTapped)
                    }
                )
            }
        }
    }
}
#endif
