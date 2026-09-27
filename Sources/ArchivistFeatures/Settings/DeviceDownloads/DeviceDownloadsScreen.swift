#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DeviceDownloadsReducer.self)
public struct DeviceDownloadsScreen: View {
    @Bindable public var store: StoreOf<DeviceDownloadsReducer>

    public init(store: StoreOf<DeviceDownloadsReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let iPhoneColumns = [GridItem(.flexible())]
    private let iPadColumns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    public var body: some View {
        ScrollView {
            if store.downloads.isEmpty {
                EmptyStateView(
                    icon: "arrow.down.to.line",
                    title: String.localised("video.empty.noDeviceDownloads", table: .videos),
                    description: String.localised("video.empty.deviceDownloadDescription", table: .videos)
                )
            } else {
                LazyVGrid(
                    columns: sizeClass == .regular ? iPadColumns : iPhoneColumns,
                    spacing: 16
                ) {
                    ForEach(store.downloads) { download in
                        VideoCardView(
                            data: download.cardData,
                            serverConfig: store.serverConfig
                        )
                        .contextMenu {
                            if let url = download.shareURL {
                                ShareLink(item: url) {
                                    Label(
                                        String.localised("generic.share", table: .generic),
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                            }

                            if download.isCompleted {
                                Button {
                                    send(.addToPlaylistTapped(download))
                                } label: {
                                    Label(
                                        String.localised("video.addToPlaylist", table: .videos),
                                        systemImage: "text.badge.plus"
                                    )
                                }
                            }

                            Button(role: .destructive) {
                                send(.deleteTapped(download.id))
                            } label: {
                                Label(
                                    String.localised("video.deleteDownload", table: .videos),
                                    systemImage: "trash"
                                )
                            }
                        }
                        .pressable { send(.downloadTapped(download)) }
                        .transition(.asymmetric(
                            insertion: .identity,
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    }
                }
                .animation(.default, value: store.downloads.map(\.id))
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            DeviceStorageBar(
                fraction: store.downloadsFraction,
                downloadsText: store.downloadsSizeText,
                availableText: store.availableStorageText
            )
        }
        .background(Color.Brand.primary)
        .onAppear { send(.viewDidAppear) }
        .onDisappear { send(.viewDidDisappear) }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(String.localised("video.saved", table: .videos))
        .alert($store.scope(state: \.alert, action: \.alert))
        .sheet(item: $store.scope(state: \.playlistPicker, action: \.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
        .fullScreenCover(item: $store.scope(state: \.videoDetail, action: \.videoDetail)) { detailStore in
            NavigationStack {
                VideoDetailScreen(store: detailStore)
            }
        }
    }
}

/// How much room the app's downloads take against what's still free.
private struct DeviceStorageBar: View {
    let fraction: Double?
    let downloadsText: String
    let availableText: String

    var body: some View {
        VStack(spacing: 10) {
            if let fraction {
                ProgressView(value: fraction)
                    .tint(Color.Accent.dark)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.Accent.dark)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(downloadsText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.Text.primary)

                Spacer()

                Text(availableText)
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }
}
#endif
