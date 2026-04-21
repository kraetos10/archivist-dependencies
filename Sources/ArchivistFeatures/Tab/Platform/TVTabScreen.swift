#if os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct TVTabScreen: View {
    @Bindable public var store: StoreOf<TabReducer>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<TabReducer>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectTab)) {
            TVHomeScreen(store: store)
                .tabItem {
                    Label(String.localised("generic.home", table: .generic), systemImage: "house")
                }
                .tag(AppTab.home)

            TVSearchScreen(store: store.scope(state: \.search, action: \.search))
            .tabItem {
                Label(String(localized: "Search"), systemImage: "magnifyingglass")
            }
            .tag(AppTab.channels)

            NavigationStack {
                DownloadsScreen(store: store.scope(state: \.queue, action: \.queue))
            }
            .tabItem {
                Label(String.localised("settings.queue", table: .settings), systemImage: "arrow.down.circle")
            }
            .tag(AppTab.queue)

            TVSettingsScreen(store: store.scope(state: \.settings, action: \.settings))
                .tabItem {
                    Label(String.localised("generic.settings", table: .generic), systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .onAppear { store.send(.appeared) }
        .onChange(of: scenePhase) {
            store.send(.scenePhaseChanged(scenePhase))
        }
    }
}
#endif
