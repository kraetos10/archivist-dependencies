#if !os(tvOS)
import ArchivistNetworking
import ArchivistComponents
import ComposableArchitecture
internal import SQLiteData
import StructuredQueries
import SwiftUI

@ViewAction(for: DeviceDownloadsReducer.self)
public struct DeviceDownloadsScreen: View {
    public let store: StoreOf<DeviceDownloadsReducer>

    public init(store: StoreOf<DeviceDownloadsReducer>) {
        self.store = store
    }

    @FetchAll(DeviceDownload.order { $0.createdAt.desc() }) var downloads
    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        ScrollView {
            if downloads.isEmpty {
                emptyStateView
            } else if sizeClass == .regular {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                    ForEach(downloads) { download in
                        downloadCard(download)
                    }
                }
                .padding()
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(downloads) { download in
                        downloadRow(download)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            storageOverlay
        }
        .background(Color.Brand.primary)
        .onAppear { send(.viewDidAppear) }
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .navigationTitle(String(localized: "Device Downloads"))
    }

    private func downloadRow(_ download: DeviceDownload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            thumbnailView(download)

            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(2)

                HStack(spacing: 0) {
                    Text(download.channelName)
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)

                    Spacer()

                    statusView(download)
                }

                if download.status == .downloading {
                    ProgressView(value: min(download.progress, 1.0))
                        .tint(Color.Accent.dark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .contextMenu {
            if download.status == .completed {
                Button(role: .destructive) {
                    send(.deleteTapped(download.id))
                } label: {
                    Label(String(localized: "Delete Download"), systemImage: "trash")
                }
            }
        }
        .pressable { send(.downloadTapped(download)) }
    }

    private func downloadCard(_ download: DeviceDownload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnailView(download)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(download.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.Text.primary)
                    .lineLimit(2)

                Text(download.channelName)
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)

                statusView(download)

                if download.status == .downloading {
                    ProgressView(value: min(download.progress, 1.0))
                        .tint(Color.Accent.dark)
                }
            }
            .padding(.horizontal, 4)
        }
        .contextMenu {
            if download.status == .completed {
                Button(role: .destructive) {
                    send(.deleteTapped(download.id))
                } label: {
                    Label(String(localized: "Delete Download"), systemImage: "trash")
                }
            }
        }
        .pressable { send(.downloadTapped(download)) }
    }

    @ViewBuilder
    private func thumbnailView(_ download: DeviceDownload) -> some View {
        if let thumbPath = download.thumbUrl,
           let thumbURL = store.serverConfig.fullURL(for: thumbPath) {
            AsyncImage(url: thumbURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(16 / 9, contentMode: .fill)
                default:
                    Rectangle()
                        .fill(Color.Brand.secondary.opacity(0.3))
                        .aspectRatio(16 / 9, contentMode: .fill)
                }
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipped()
        } else {
            Rectangle()
                .fill(Color.Brand.secondary.opacity(0.3))
                .aspectRatio(16 / 9, contentMode: .fit)
        }
    }

    @ViewBuilder
    private func statusView(_ download: DeviceDownload) -> some View {
        switch download.status {
        case .downloading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                    .tint(Color.Accent.dark)
                Text(download.progress > 0
                     ? "\(Int(download.progress * 100))%"
                     : String(localized: "Downloading"))
                    .font(.caption)
                    .foregroundStyle(Color.Accent.dark)
            }
        case .completed:
            Label(String(localized: "Downloaded"), systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.Accent.dark)
        case .failed:
            Label(String(localized: "Tap to Retry"), systemImage: "arrow.clockwise.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        case .none:
            EmptyView()
        }
    }

    private var storageOverlay: some View {
        VStack(spacing: 6) {
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
                .frame(height: 6)
            }

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.Accent.dark)
                    .frame(width: 8, height: 8)
                Text("Downloads: \(formattedBytes(store.downloadsSize))")
                    .font(.caption)
                    .foregroundStyle(Color.Text.primary)

                Spacer()

                Text("\(formattedBytes(store.availableStorage)) available of \(formattedBytes(store.totalStorage))")
                    .font(.caption)
                    .foregroundStyle(Color.Brand.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
            title: String(localized: "No Device Downloads"),
            description: String(localized: "Videos you download to this device will appear here.")
        )
    }
}
#endif
