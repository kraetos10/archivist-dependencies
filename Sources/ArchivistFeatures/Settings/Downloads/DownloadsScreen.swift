import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DownloadsReducer.self)
public struct DownloadsScreen: View {
    @Bindable public var store: StoreOf<DownloadsReducer>

    public init(store: StoreOf<DownloadsReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 400), spacing: 48)]
        #else
        if horizontalSizeClass == .regular {
            [GridItem(.adaptive(minimum: 300), spacing: 16)]
        } else {
            [GridItem(.flexible())]
        }
        #endif
    }

    public var body: some View {
        ScrollView {
            queueContent
        }
        .background(Color.Brand.primary.ignoresSafeArea())
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(String(localized: "Queue"))
        #endif
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $store.searchQuery,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: String(localized: "Search queue")
        )
        #endif
        .onAppear { send(.viewDidAppear) }
        .alert($store.scope(state: \.alert, action: \.alert))
    }

    // MARK: - Queue Content

    private var queueContent: some View {
        Group {
            if store.hasLoaded && store.filteredDownloads.isEmpty && store.searchQuery.isEmpty {
                EmptyStateView(icon: "arrow.down.circle", title: String(localized: "No downloads yet"), description: String(localized: "Downloads from your server will appear here."))
            } else if store.hasLoaded && store.filteredDownloads.isEmpty && !store.searchQuery.isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: String(localized: "No search results"), description: String(localized: "Try a different search term."))
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    if store.isLoading && store.downloads.isEmpty {
                        ForEach(DownloadResponse.placeholders) { download in
                            #if os(tvOS)
                            TVVideoCardView(
                                download: download,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                            #else
                            VideoCardView(
                                download: download,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                            #endif
                        }
                    } else {
                        ForEach(store.filteredDownloads) { download in
                            #if os(tvOS)
                            TVVideoCardView(
                                download: download,
                                serverConfig: store.serverConfig
                            ) {
                                send(.downloadTapped(download))
                            }
                            .onAppear {
                                if download.id == store.downloads.last?.id {
                                    send(.lastItemAppeared)
                                }
                            }
                            #else
                            DownloadQueueCardWithPopover(
                                download: download,
                                store: store,
                                onDelete: { send(.deleteTapped(download)) }
                            )
                            .onAppear {
                                if download.id == store.downloads.last?.id {
                                    send(.lastItemAppeared)
                                }
                            }
                            #endif
                        }
                    }
                }
                .padding()

                if store.isLoadingMore {
                    ProgressView()
                        .tint(Color.Progress.tint)
                        .padding()
                }
            }
        }
    }
}

#if !os(tvOS)
private struct DownloadQueueCardWithPopover: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<DownloadsReducer>
    var onDelete: () -> Void
    @State private var showPopover = false
    @State private var showSheet = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        VideoCardView(
            download: download,
            serverConfig: store.serverConfig
        )
        .pressable {
            store.send(.view(.downloadTapped(download)))
            if sizeClass == .regular {
                showPopover = true
            } else {
                showSheet = true
            }
        }
        .contextMenu {
            ShareLink(item: download.youtubeURL) {
                Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
        }
        .popover(isPresented: $showPopover) {
            if let detailStore = store.scope(state: \.downloadDetail, action: \.downloadDetail.presented) {
                DownloadDetailScreen(store: detailStore)
                    .frame(idealWidth: 420)
            }
        }
        .sheet(isPresented: $showSheet) {
            if let detailStore = store.scope(state: \.downloadDetail, action: \.downloadDetail.presented) {
                DownloadDetailScreen(store: detailStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: store.downloadDetail == nil) { _, isNil in
            if isNil {
                showPopover = false
                showSheet = false
            }
        }
    }
}
#endif
