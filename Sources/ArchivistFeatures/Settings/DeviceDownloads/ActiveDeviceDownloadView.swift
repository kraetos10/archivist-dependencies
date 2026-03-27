#if !os(tvOS)
internal import SQLiteData
import ArchivistNetworking
import StructuredQueries
import SwiftUI
import ArchivistComponents

public struct ActiveDeviceDownloadView: View {
    public init() {}

    @FetchAll(
        DeviceDownload
            .where { $0.status.eq(DeviceDownloadStatus.downloading) }
            .order { $0.createdAt.desc() }
    ) var activeDownloads

    public var body: some View {
        if !activeDownloads.isEmpty {
            Section {
                ForEach(activeDownloads) { download in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(Color.Accent.dark)
                            Text(download.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.Accent.dark)
                                .lineLimit(1)

                            Spacer()

                            if download.progress > 0 {
                                Text("\(Int(download.progress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(Color.Brand.secondary)
                            }
                        }

                        ProgressView(value: min(download.progress, 1.0))
                            .tint(Color.Accent.dark)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text(String.localised("video.deviceDownloads", table: .videos))
            }
        }
    }
}
#endif
