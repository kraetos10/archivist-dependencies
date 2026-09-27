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

    #if os(tvOS)
    /// Mirrors `store.focusedDownloadID`, so the reducer can hand focus to
    /// the neighbouring card when the focused one leaves the queue.
    @FocusState private var focusedDownloadID: String?
    #endif

    private var columns: [GridItem] {
        #if os(tvOS)
        TVLayout.cardGridColumns
        #else
        if horizontalSizeClass == .regular {
            Array(repeating: GridItem(.flexible(), spacing: 16), count: 4)
        } else {
            [GridItem(.flexible())]
        }
        #endif
    }

    public var body: some View {
        ScrollView {
            #if os(tvOS)
            // tvOS settings sub-screens title themselves in the content
            // (the navigation bar title is blanked under the tab bar).
            Text(String.localised("settings.queue", table: .settings))
                .font(.title2)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, TVLayout.rowVerticalPadding)
            #endif

            queueContent
        }
        .scrollPosition(id: $store.scrollPositionID, anchor: .center)
        #if os(tvOS)
        .bind($store.focusedDownloadID, to: $focusedDownloadID)
        #endif
        .background(Color.Brand.primary.ignoresSafeArea())
        .refreshable { await send(.pullToRefreshTriggered).finish() }
        #if os(tvOS)
        .navigationTitle("")
        #else
        .navigationTitle(String.localised("settings.queue", table: .settings))
        #endif
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $store.searchQuery,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: String.localised("video.searchQueue", table: .videos)
        )
        #endif
        .onAppear { send(.viewDidAppear) }
        #if !os(tvOS)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker(selection: $store.sortOrder.sending(\.view.sortOrderChanged)) {
                        Text(String.localised("generic.descending", table: .generic))
                            .tag(DownloadSortOrder.newestFirst)
                        Text(String.localised("generic.ascending", table: .generic))
                            .tag(DownloadSortOrder.oldestFirst)
                    } label: {
                        EmptyView()
                    }
                } label: {
                    Label(
                        String.localised("generic.sort", table: .generic),
                        systemImage: "arrow.up.arrow.down"
                    )
                    .labelStyle(.iconOnly)
                    .foregroundStyle(Color.Accent.dark)
                }
            }
        }
        #endif
        .alert($store.scope(state: \.alert, action: \.alert))
        #if !os(tvOS)
        .modifier(DownloadDetailSheetPresentation(store: store, sizeClass: horizontalSizeClass))
        #endif
    }

    private var gridSpacing: CGFloat {
        #if os(tvOS)
        TVLayout.cardSpacing
        #else
        16
        #endif
    }

    // MARK: - Queue Content

    private var queueContent: some View {
        // Read once per pass rather than per row.
        let filtered = store.filteredDownloads

        return Group {
            if store.showsEmptyQueue {
                EmptyStateView(
                    icon: "arrow.down.circle",
                    title: String.localised("video.empty.noDownloads", table: .videos),
                    description: String.localised("video.empty.downloadsDescription", table: .videos)
                )
            } else if store.showsNoSearchResults {
                EmptyStateView(
                    icon: "magnifyingglass",
                    title: String.localised("video.empty.noSearchResults", table: .videos),
                    description: String.localised("video.empty.tryDifferentSearch", table: .videos)
                )
            } else {
                LazyVGrid(columns: columns, spacing: gridSpacing) {
                    if store.showsPlaceholders {
                        ForEach(DownloadResponse.placeholders) { download in
                            #if os(tvOS)
                            TVVideoCardView(
                                download: download,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                            .disabled(true)
                            #else
                            VideoCardView(
                                download: download,
                                serverConfig: store.serverConfig
                            )
                            .redacted(reason: .placeholder)
                            #endif
                        }
                    } else {
                        ForEach(filtered) { download in
                            #if os(tvOS)
                            TVVideoCardView(
                                download: download,
                                serverConfig: store.serverConfig
                            ) {
                                send(.downloadTapped(download))
                            }
                            .focused($focusedDownloadID, equals: download.id)
                            .onAppear { send(.itemAppeared(download.id)) }
                            #else
                            DownloadQueueCardWithPopover(
                                download: download,
                                store: store,
                                onDelete: { send(.deleteTapped(download)) }
                            )
                            .onAppear { send(.itemAppeared(download.id)) }
                            #endif
                        }
                    }
                }
                // Without it `scrollPosition(id:)` has no ids to resolve,
                // so the scroll after a removal did nothing.
                .scrollTargetLayout()
                .animation(.default, value: filtered.map(\.id))
                #if os(tvOS)
                .padding(.vertical, TVLayout.rowVerticalPadding)
                #else
                .padding()
                #endif

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
    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        VideoCardView(
            download: download,
            serverConfig: store.serverConfig
        )
        .pressable {
            store.send(.view(.downloadTapped(download)))
            // Compact presents from the screen, bound straight to store
            // state; only the iPad popover needs a local flag, because it
            // has to anchor to this card.
            if sizeClass == .regular {
                showPopover = true
            }
        }
        .contextMenu {
            if let url = download.youtubeURL {
                ShareLink(item: url) {
                    Label(String.localised("generic.share", table: .generic), systemImage: "square.and.arrow.up")
                }
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(String.localised("generic.delete", table: .generic), systemImage: "trash")
            }
        }
        .popover(isPresented: $showPopover) {
            if let detailStore = store.scope(state: \.downloadDetail, action: \.downloadDetail.presented) {
                DownloadDetailScreen(store: detailStore)
                    .frame(idealWidth: 420)
            }
        }
        .onChange(of: store.downloadDetail == nil) { _, isNil in
            if isNil {
                showPopover = false
            }
        }
        // Tapping outside dismisses the popover without going through the
        // store; close the presented state too, or its effects outlive it.
        .onChange(of: showPopover) { _, isShowing in
            if !isShowing, store.downloadDetail != nil {
                store.send(.downloadDetail(.dismiss))
            }
        }
    }
}

/// Presents the download detail as a sheet on compact widths.
///
/// Attached once at the screen and driven by `$store.scope` rather than
/// per-card with an `isPresented` flag. With a flag, queueing a download
/// nil-ed the presentation state one pass before `onChange` could lower
/// the flag, so the sheet's `if let` content emptied while it was still
/// presented — it expanded to the large detent, flashed white, and only
/// then dismissed. A single binding ends content and presentation
/// together.
///
/// iPad keeps its per-card popover so the arrow still points at the card
/// that was tapped.
private struct DownloadDetailSheetPresentation: ViewModifier {
    @Bindable var store: StoreOf<DownloadsReducer>
    let sizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
        } else {
            content.sheet(
                item: $store.scope(state: \.downloadDetail, action: \.downloadDetail)
            ) { detailStore in
                DownloadDetailScreen(store: detailStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
#endif
