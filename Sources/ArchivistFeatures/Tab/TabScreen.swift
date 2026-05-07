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

            NavigationStack {
                DownloadsScreen(store: store.scope(state: \.queue, action: \.queue))
            }
            .tabItem {
                Label(String.localised("settings.queue", table: .settings), systemImage: "arrow.down.circle")
            }
            .tag(AppTab.queue)

            settingsTab
        }
        .tint(Color.Accent.dark)
        .onAppear { store.send(.appeared) }
        .onChange(of: scenePhase) {
            store.send(.scenePhaseChanged(scenePhase))
        }
        .sheet(isPresented: $store.isPresentingSettingsPin) {
            PinEntrySheet(
                expectedPin: store.childModePin,
                onSuccess: { store.send(.settingsPinSucceeded) },
                onCancel: { store.send(.settingsPinDismissed) }
            )
        }
    }

    @ViewBuilder
    private var settingsTab: some View {
        if store.childModeEnabled, !store.settingsUnlocked {
            PinLockedSettingsPlaceholder()
                .tabItem {
                    Label(String.localised("generic.settings", table: .generic), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        } else {
            SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label(String.localised("generic.settings", table: .generic), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
                .badge(store.activeDownload != nil ? 1 : 0)
        }
    }
}

private struct PinLockedSettingsPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.Accent.dark)
            Text(String.localised("childMode.pinEntry.subtitle", table: .login))
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
    }
}

// In-app mini player removed. The dismiss flow on `VideoDetailReducer`
// hands off to system PiP via `PlayerManager.startPiPIfAvailable()`; if the
// platform won't grant PiP we just stop the player.
#endif
