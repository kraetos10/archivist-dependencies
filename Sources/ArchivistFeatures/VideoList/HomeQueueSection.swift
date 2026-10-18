#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

/// The home page's Queue strip: videos waiting in the server's download
/// queue. Laid out like the other home carousels, but marked as not
/// available yet — a dashed outline, a line saying so, and greyed cards
/// with a download badge. Tapping a card opens the same download screen
/// as the Queue screen.
struct HomeQueueSection: View {
    @Bindable var store: StoreOf<VideoListReducer>
    let downloads: [DownloadResponse]
    let cardWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Label(
                    String.localised("video.downloadQueue", table: .videos),
                    systemImage: "tray.and.arrow.down"
                )
                .font(.headline)
                .foregroundStyle(Color.Text.primary)
                .accessibilityAddTraits(.isHeader)

                Text(String.localised("video.downloadQueue.hint", table: .videos))
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            ScrollView(.horizontal) {
                LazyHStack(alignment: .center, spacing: 12) {
                    ForEach(downloads) { download in
                        HomeQueueCard(
                            download: download,
                            store: store
                        )
                        .frame(width: cardWidth)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.Surface.highlight.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.Brand.secondary.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .accessibilityHidden(true)
        )
        .padding(.horizontal, 12)
    }
}

/// A queued video's card. iPad anchors the download screen to the card as
/// a popover; compact widths get the sheet from `HomeQueueDetailSheet`.
private struct HomeQueueCard: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<VideoListReducer>
    @State private var showPopover = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VideoCardView(
            download: download,
            serverConfig: store.serverConfig
        )
        .pressable {
            store.send(.view(.queuedDownloadTapped(download)))
            if sizeClass == .regular {
                showPopover = true
            }
        }
        .accessibilityHint(String.localised("video.downloadQueue.hint", table: .videos))
        .popover(isPresented: $showPopover) {
            if let detailStore = store.scope(
                state: \.destination?.downloadDetail,
                action: \.destination.downloadDetail
            ) {
                DownloadDetailScreen(store: detailStore)
                    .frame(idealWidth: 420)
            }
        }
        .onChange(of: store.destination?.downloadDetail == nil) { _, isNil in
            if isNil {
                showPopover = false
            }
        }
        // Tapping outside dismisses the popover without going through the
        // store; close the presented state too, or its effects outlive it.
        .onChange(of: showPopover) { _, isShowing in
            if !isShowing, store.destination?.downloadDetail != nil {
                store.send(.destination(.dismiss))
            }
        }
    }
}

/// Presents a queued video's download screen as a sheet on compact
/// widths, bound straight to the store so content and presentation end
/// together (see `DownloadDetailSheetPresentation`). iPad keeps the
/// per-card popover.
struct HomeQueueDetailSheet: ViewModifier {
    @Bindable var store: StoreOf<VideoListReducer>
    let sizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
        } else {
            content.sheet(
                item: $store.scope(
                    state: \.destination?.downloadDetail,
                    action: \.destination.downloadDetail
                )
            ) { detailStore in
                DownloadDetailScreen(store: detailStore)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}
#endif
