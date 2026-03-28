#if os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: VideoListReducer.self)
public struct TVVideoListScreen: View {
    @Bindable public var store: StoreOf<VideoListReducer>

    public init(store: StoreOf<VideoListReducer>) {
        self.store = store
    }

    private let columns = [GridItem(.adaptive(minimum: 400), spacing: 48)]

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            ScrollView {
                HStack {
                    WatchFilterRow(
                        watchFilter: store.watchFilter,
                        onFilterChanged: { send(.watchFilterChanged($0)) }
                    )

                    Spacer()

                    HStack(spacing: 12) {
                        ForEach(VideoSortOrder.allCases, id: \.self) { sort in
                            let isSelected = store.sortOrder == sort
                            Button {
                                send(.sortOrderChanged(sort))
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: sort.icon)
                                    Text(sort.label)
                                }
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(isSelected ? Color.Brand.primary : Color.Text.primary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(isSelected ? Color.Text.primary : Color.Surface.highlight)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(TVCapsuleButtonStyle())
                        }
                    }
                    .padding(.trailing, 48)
                }
                .padding(.top, 16)
                .focusSection()

                if store.hasLoaded && store.displayedVideos.isEmpty {
                    emptyStateView
                } else {
                    videoGridContent
                        .focusSection()
                }
            }
            .onAppear {
                if store.videos.isEmpty {
                    send(.viewDidAppear)
                } else {
                    send(.pullToRefreshTriggered)
                }
            }
            .alert($store.scope(state: \.alert, action: \.alert))
        } destination: { store in
            switch store.case {
            case .videoDetail(let detailStore):
                TVVideoDetailScreen(store: detailStore)
            }
        }
    }

    private var videoGridContent: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: columns, spacing: 48) {
                if store.isLoading && store.videos.isEmpty {
                    placeholderCards
                } else {
                    videoCards
                }
            }
            .padding(48)

            if store.isLoadingMore {
                ProgressView()
                    .padding()
            }
        }
    }

    private var placeholderCards: some View {
        ForEach(VideoResponse.placeholders) { video in
            TVVideoCardView(
                video: video,
                serverConfig: store.serverConfig
            )
            .redacted(reason: .placeholder)
        }
    }

    private var videoCards: some View {
        ForEach(store.displayedVideos) { item in
            TVVideoCardView(
                video: item.video,
                serverConfig: store.serverConfig
            ) {
                send(.videoTapped(item.video))
            }
            .onAppear {
                if item.video.id == store.videos.last?.id {
                    send(.lastItemAppeared)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 120)
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text(String.localised("video.empty.noVideos", table: .videos))
                .font(.title2)
            Text(String.localised("video.empty.serverDescription", table: .videos))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
