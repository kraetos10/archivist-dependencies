#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelsReducer.self)
public struct iPadChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 250), spacing: 16)]

    public var body: some View {
        NavigationSplitView {
            ChannelsGridContent(
                store: store,
                columns: columns,
                highlightsSelection: true
            )
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Spacer()
                    FloatingAddButton(
                        accessibilityLabel: String.localised("login.addChannel", table: .login)
                    ) {
                        send(.addChannelTapped)
                    }
                    .button
                    .popover(item: $store.scope(state: \.addChannel, action: \.addChannel)) { addChannelStore in
                        AddChannelScreen(store: addChannelStore)
                            .frame(width: 400)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle(String.localised("generic.channels", table: .generic))
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $store.searchQuery,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: String.localised("login.searchChannels", table: .login)
            )
            .background(Color.Brand.primary)
            .onAppear { send(.splitViewDidAppear) }
            .alert($store.scope(state: \.alert, action: \.alert))
            .navigationSplitViewColumnWidth(min: 300, ideal: 350, max: 450)
        } detail: {
            if let detailStore = store.scope(state: \.selectedChannel, action: \.channelDetail.presented) {
                ChannelDetailScreen(store: detailStore)
            } else {
                ChannelsEmptyDetailView()
            }
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
}

/// The split view's detail column before any channel is picked.
private struct ChannelsEmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.crop.rectangle.stack")
                .scaledSystemFont(size: 48, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(Color.Brand.secondary)
            Text(String.localised("channel.selectPrompt", table: .login))
                .font(.headline)
                .foregroundStyle(Color.Brand.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.Brand.primary)
    }
}
#endif
