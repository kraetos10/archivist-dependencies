#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
internal import SQLiteData
import StructuredQueries
import SwiftUI

@ViewAction(for: DeviceDownloadsReducer.self)
public struct DeviceDownloadsScreen: View {
    @Bindable public var store: StoreOf<DeviceDownloadsReducer>

    public init(store: StoreOf<DeviceDownloadsReducer>) {
        self.store = store
    }

    @FetchAll(DeviceDownload.order { $0.createdAt.desc() }) var downloads
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let iPhoneColumns = [GridItem(.flexible())]
    private let iPadColumns = [GridItem(.adaptive(minimum: 300), spacing: 16)]

    public var body: some View {
        ScrollView {
            if downloads.isEmpty {
                emptyStateView
            } else {
                LazyVGrid(
                    columns: sizeClass == .regular ? iPadColumns : iPhoneColumns,
                    spacing: 16
                ) {
                    ForEach(downloads) { download in
                        VideoCardView(
                            data: cardData(for: download),
                            serverConfig: store.serverConfig
                        )
                        .overlay(alignment: .bottom) {
                            if download.status == .downloading {
                                ProgressView(value: min(max(download.progress, 0), 1.0))
                                    .tint(Color.Accent.dark)
                                    .scaleEffect(y: 2)
                                    .padding(.horizontal, 12)
                                    .padding(.bottom, 4)
                                    .animation(.easeInOut(duration: 0.3), value: download.progress)
                            }
                        }
                        .padding(.bottom, download.status == .downloading ? 12 : 0)
                        .contextMenu {
                            if let url = URL(string: "https://www.youtube.com/watch?v=\(download.id)") {
                                ShareLink(item: url) {
                                    Label(
                                        String.localised("generic.share", table: .generic),
                                        systemImage: "square.and.arrow.up"
                                    )
                                }
                            }

                            if download.status == .completed {
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
                .animation(.default, value: downloads.map(\.id))
                .padding()
            }
        }
        .safeAreaInset(edge: .bottom) {
            storageOverlay
        }
        .background(Color.Brand.primary)
        .onAppear { send(.viewDidAppear) }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(String.localised("video.deviceDownloads", table: .videos))
        .sheet(item: $store.scope(state: \.playlistPicker, action: \.playlistPicker)) { pickerStore in
            PlaylistPickerScreen(store: pickerStore)
        }
    }

    private func cardData(for download: DeviceDownload) -> CardData {
        let fileSizeStr: String? = {
            guard let bytes = download.fileSize else { return nil }
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return formatter.string(fromByteCount: Int64(bytes))
        }()

        let statusText: String? = {
            switch download.status {
            case .downloading:
                return download.progress > 0
                    ? "\(Int(download.progress * 100))%"
                    : String.localised("video.downloading", table: .videos)
            case .failed:
                return String.localised("generic.tapToRetry", table: .generic)
            case .completed, .none:
                return nil
            }
        }()

        return CardData(
            title: download.title,
            channelName: download.channelName,
            thumbPath: download.thumbUrl,
            duration: nil,
            publishedRelative: statusText,
            isWatched: false,
            isPartiallyWatched: false,
            watchProgress: 0,
            isPending: false,
            isDownloaded: download.status == .completed,
            fileSize: fileSizeStr
        )
    }

    private var storageOverlay: some View {
        VStack(spacing: 10) {
            if store.totalStorage > 0 {
                let usedFraction = Double(store.totalStorage - store.availableStorage) / Double(store.totalStorage)
                let downloadsFraction = Double(store.downloadsSize) / Double(store.totalStorage)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.Brand.secondary.opacity(0.3))
                        Capsule()
                            .fill(Color.Brand.secondary.opacity(0.6))
                            .frame(width: geo.size.width * usedFraction)
                        Capsule()
                            .fill(Color.Accent.dark)
                            .frame(width: geo.size.width * downloadsFraction)
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(Color.Accent.dark)
                    .frame(width: 10, height: 10)
                Text("Downloads: \(formattedBytes(store.downloadsSize))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.Text.primary)

                Spacer()

                Text("\(formattedBytes(store.availableStorage)) available")
                    .font(.subheadline)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private var emptyStateView: some View {
        EmptyStateView(
            icon: "arrow.down.to.line",
            title: String.localised("video.empty.noDeviceDownloads", table: .videos),
            description: String.localised("video.empty.deviceDownloadDescription", table: .videos)
        )
    }
}
#endif
