#if os(tvOS)
import ArchivistComponents
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
            Tab(
                String.localised("generic.home", table: .generic),
                systemImage: "house",
                value: AppTab.home
            ) {
                TVHomeScreen(store: store)
            }

            Tab(
                String.localised("generic.search", table: .generic),
                systemImage: "magnifyingglass",
                value: AppTab.search
            ) {
                TVSearchScreen(store: store.scope(state: \.search, action: \.search))
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
                TVSettingsScreen(store: store.scope(state: \.settings, action: \.settings))
            }
        }
        .onAppear { store.send(.appeared) }
    }
}
#endif
