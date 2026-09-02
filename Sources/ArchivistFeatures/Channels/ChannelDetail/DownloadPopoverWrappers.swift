#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

struct DownloadCardWithPopover: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<ChannelDetailReducer>
    @State private var showPopover = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VideoCardView(
            download: download,
            serverConfig: store.serverConfig
        )
        .modifier(DownloadPopoverModifier(
            store: store,
            download: download,
            showPopover: $showPopover,
            sizeClass: sizeClass
        ))
    }
}

struct DownloadRowWithPopover: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<ChannelDetailReducer>
    @State private var showPopover = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        VideoRowView(
            title: download.title ?? "",
            subtitle: download.publishedRelative,
            thumbnailURL: download.thumbURL(config: store.serverConfig)
        )
        .modifier(DownloadPopoverModifier(
            store: store,
            download: download,
            showPopover: $showPopover,
            sizeClass: sizeClass
        ))
    }
}

private struct DownloadPopoverModifier: ViewModifier {
    @Bindable var store: StoreOf<ChannelDetailReducer>
    let download: DownloadResponse
    @Binding var showPopover: Bool
    let sizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        content
            .pressable {
                store.send(.view(.downloadCardTapped(download)))
                // Compact presents from the screen, bound straight to store
                // state; only the iPad popover needs a local flag, because
                // it has to anchor to this card.
                if sizeClass == .regular {
                    showPopover = true
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
struct ChannelDownloadDetailSheet: ViewModifier {
    @Bindable var store: StoreOf<ChannelDetailReducer>
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
