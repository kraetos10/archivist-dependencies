#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ChannelsReducer.self)
public struct TVChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                VStack(alignment: .leading, spacing: TVLayout.cardSpacing) {
                    filterRow

                    if store.hasLoaded && store.filteredChannels.isEmpty && store.filter == .withUnwatched {
                        emptyUnwatchedView
                    } else if store.hasLoaded && store.filteredChannels.isEmpty {
                        emptyStateView
                    } else {
                        channelGrid

                        if store.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, TVLayout.rowVerticalPadding)
            }
            .navigationTitle("")
        } destination: { store in
            switch store.case {
            case .channelDetail(let detailStore):
                TVChannelDetailScreen(store: detailStore)
            }
        }
        .onAppear { send(.viewDidAppear) }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                TVVideoDetailScreen(store: detailStore)
                    .background(Color.Brand.primary)
            }
            .background(Color.Brand.primary)
        }
    }

    // MARK: - Filter

    /// Capsule chips rather than a segmented picker: a tvOS segmented
    /// control changes selection as focus sweeps across it, reshuffling
    /// the grid on every swipe. A chip only applies on select.
    private var filterRow: some View {
        HStack(spacing: 12) {
            filterChip(
                .all,
                title: String.localised("generic.all", table: .generic)
            )
            filterChip(
                .withUnwatched,
                title: String.localised("generic.unwatched", table: .generic)
            )
        }
        .focusSection()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String.localised("login.channelFilter", table: .login))
    }

    private func filterChip(
        _ filter: ChannelListFilter,
        title: String
    ) -> some View {
        let isSelected = store.filter == filter
        return Button {
            send(.filterChanged(filter), animation: .default)
        } label: {
            Text(title)
        }
        .buttonStyle(TVCapsuleButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Grid

    private var channelGrid: some View {
        LazyVGrid(columns: TVLayout.channelGridColumns, spacing: TVLayout.cardSpacing) {
            if store.isLoading && store.filteredChannels.isEmpty {
                ForEach(ChannelResponse.placeholders) { channel in
                    TVChannelCardView(
                        channel: channel,
                        serverConfig: store.serverConfig
                    )
                    .redacted(reason: .placeholder)
                    .disabled(true)
                }
            } else {
                ForEach(store.filteredChannels) { channel in
                    TVChannelCardView(
                        channel: channel,
                        serverConfig: store.serverConfig
                    ) {
                        send(.channelTapped(channel))
                    }
                    // Anchor on the rendered list: under the Unwatched
                    // filter the unfiltered list's last channel is never
                    // drawn, so paging would stop at page one.
                    .onAppear {
                        if channel.id == store.filteredChannels.last?.id {
                            send(.lastItemAppeared)
                        }
                    }
                }
            }
        }
        .focusSection()
    }

    // MARK: - Empty states

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "person.2.rectangle.stack")
                .scaledSystemFont(size: 64, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(.secondary)
            Text(String.localised("login.noChannels", table: .login))
                .font(.title2)
            Text(String.localised("login.subscribeChannelsDescription", table: .login))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyUnwatchedView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "eye.slash")
                .scaledSystemFont(size: 64, relativeTo: .largeTitle)
                // Decorative: the adjacent label carries the meaning.
                .accessibilityHidden(true)
                .foregroundStyle(.secondary)
            Text(String.localised("video.empty.noUnwatched", table: .videos))
                .font(.title2)
            Text(String.localised("generic.noNewVideosDescription", table: .generic))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
