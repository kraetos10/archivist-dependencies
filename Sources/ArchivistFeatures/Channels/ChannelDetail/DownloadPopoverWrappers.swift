#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

struct DownloadCardWithPopover: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<ChannelDetailReducer>
    @State private var showPopover = false
    @State private var showSheet = false
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
            showSheet: $showSheet,
            sizeClass: sizeClass
        ))
    }
}

struct DownloadRowWithPopover: View {
    let download: DownloadResponse
    @Bindable var store: StoreOf<ChannelDetailReducer>
    @State private var showPopover = false
    @State private var showSheet = false
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
            showSheet: $showSheet,
            sizeClass: sizeClass
        ))
    }
}

private struct DownloadPopoverModifier: ViewModifier {
    @Bindable var store: StoreOf<ChannelDetailReducer>
    let download: DownloadResponse
    @Binding var showPopover: Bool
    @Binding var showSheet: Bool
    let sizeClass: UserInterfaceSizeClass?

    func body(content: Content) -> some View {
        content
            .pressable {
                store.send(.view(.downloadCardTapped(download)))
                if sizeClass == .regular {
                    showPopover = true
                } else {
                    showSheet = true
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
