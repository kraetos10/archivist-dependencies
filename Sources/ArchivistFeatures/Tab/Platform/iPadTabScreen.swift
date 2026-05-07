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
                String.localised("settings.queue", table: .settings),
                systemImage: "arrow.down.circle",
                value: AppTab.queue
            ) {
                NavigationStack {
                    DownloadsScreen(store: store.scope(state: \.queue, action: \.queue))
                }
            }

            Tab(
                String.localised("generic.settings", table: .generic),
                systemImage: "gearshape",
                value: AppTab.settings
            ) {
                if store.childModeEnabled, !store.settingsUnlocked {
                    PinLockedTabPlaceholder()
                } else {
                    SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                }
            }
            .badge(store.activeDownload != nil ? 1 : 0)
        }
        .tabViewStyle(.sidebarAdaptable)
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
}

private struct PinLockedTabPlaceholder: View {
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
#endif
