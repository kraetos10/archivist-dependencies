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
                if store.hasLoaded && store.displayedVideos.isEmpty {
                    emptyStateView
                } else {
                    videoGridContent
                }
            }
            .onAppear { send(.viewDidAppear) }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        send(.pullToRefreshTriggered)
                    } label: {
                        Label(String(localized: "Refresh"), systemImage: "arrow.trianglehead.2.clockwise")
                    }
                    .disabled(store.isLoading)
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
        ForEach(store.displayedVideos) { video in
            TVVideoCardView(
                video: video,
                serverConfig: store.serverConfig
            ) {
                send(.videoTapped(video))
            }
            .onAppear {
                if video.id == store.videos.last?.id {
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
            Text(String(localized: "No videos yet"))
                .font(.title2)
            Text(String(localized: "Videos from your server will appear here."))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
#endif
