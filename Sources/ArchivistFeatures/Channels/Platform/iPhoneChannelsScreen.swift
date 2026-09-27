#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelsReducer.self)
public struct iPhoneChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ChannelsGridContent(
                store: store,
                columns: columns,
                highlightsSelection: false
            )
            .navigationTitle(String.localised("generic.channels", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: String.localised("login.searchChannels", table: .login)
            )
            .safeAreaInset(edge: .bottom) {
                FloatingAddButton(
                    accessibilityLabel: String.localised("login.addChannel", table: .login)
                ) {
                    send(.addChannelTapped)
                }
            }
            .sheet(item: $store.scope(state: \.addChannel, action: \.addChannel)) { addChannelStore in
                AddChannelScreen(store: addChannelStore)
                    .presentationDetents([.medium])
            }
        } destination: { store in
            switch store.case {
            case .channelDetail(let detailStore):
                ChannelDetailScreen(store: detailStore)
            }
        }
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
}
#endif
