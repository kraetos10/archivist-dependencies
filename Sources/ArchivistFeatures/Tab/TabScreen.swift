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
            Tab(
                String.localised("generic.home", table: .generic),
                systemImage: "house",
                value: AppTab.home
            ) {
                VideoListScreen(store: store.scope(state: \.videoList, action: \.videoList))
            }

            Tab(
                String.localised("generic.channels", table: .generic),
                systemImage: "antenna.radiowaves.left.and.right",
                value: AppTab.channels
            ) {
                ChannelsScreen(store: store.scope(state: \.channels, action: \.channels))
            }

            Tab(
                String.localised("generic.playlists", table: .generic),
                systemImage: "music.note.list",
                value: AppTab.playlists
            ) {
                PlaylistsScreen(store: store.scope(state: \.playlists, action: \.playlists))
            }

            Tab(
                String.localised("video.deviceDownloads", table: .videos),
                systemImage: "arrow.down.to.line",
                value: AppTab.deviceDownloads
            ) {
                NavigationStack {
                    DeviceDownloadsScreen(
                        store: store.scope(state: \.deviceDownloads, action: \.deviceDownloads)
                    )
                }
            }

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

    // `TabReducer.State.selectedTab` is optional, so the `TabView`'s
    // selection — and therefore every `Tab` value in it — is `AppTab?`.
    @TabContentBuilder<AppTab?>
    private var settingsTab: some TabContent<AppTab?> {
        let title = String.localised("generic.settings", table: .generic)
        if store.childModeEnabled, !store.settingsUnlocked {
            Tab(title, systemImage: "gearshape", value: AppTab.settings) {
                PinLockedSettingsPlaceholder()
            }
        } else {
            Tab(title, systemImage: "gearshape", value: AppTab.settings) {
                SettingsScreen(store: store.scope(state: \.settings, action: \.settings))
            }
            .badge(store.activeDownload != nil ? 1 : 0)
        }
    }
}

private struct PinLockedSettingsPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .scaledSystemFont(size: 40, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
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
