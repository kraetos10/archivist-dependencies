#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchDownloadsView: View {
    @State var viewModel: WatchDownloadsViewModel
    @State private var showCancelConfirmation = false
    @State private var selectedRecord: WatchDownload?
    let config: ServerConfig

    public init(
        viewModel: WatchDownloadsViewModel,
        config: ServerConfig
    ) {
        self.viewModel = viewModel
        self.config = config
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.hasActiveDownload {
                    Section {
                        Button {
                            showCancelConfirmation = true
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(viewModel.activeDownloadTitle ?? "")
                                    .font(.headline)
                                    .lineLimit(1)

                                if let channel = viewModel.activeDownloadChannel {
                                    Text(channel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                ProgressView(value: viewModel.activeDownloadProgress)
                                    .tint(.green)

                                Text(
                                    String(
                                        localized: "download.progress \(Int(viewModel.activeDownloadProgress * 100))",
                                        bundle: Bundle.module
                                    )
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text(String(localized: "download.downloading", bundle: Bundle.module))
                    }
                }

                if !viewModel.records.isEmpty {
                    Section {
                        ForEach(viewModel.records) { record in
                            NavigationLink {
                                WatchNowPlayingView(
                                    viewModel: WatchAudioPlayerViewModel(
                                        videoId: record.id,
                                        title: record.title,
                                        channelName: record.channelName,
                                        thumbPath: record.thumbPath,
                                        fileURL: viewModel.fileURL(for: record.id),
                                        serverConfig: config,
                                        startPosition: record.lastPlayedPosition
                                    )
                                )
                            } label: {
                                WatchVideoRow(
                                    title: record.title,
                                    thumbPath: record.thumbPath,
                                    config: config,
                                    videoId: record.id,
                                    isWatched: false,
                                    watchProgress: viewModel.watchProgress(for: record),
                                    durationStr: record.durationStr,
                                    remainingStr: viewModel.remainingStr(for: record),
                                    onEllipsisTapped: { selectedRecord = record }
                                )
                            }
                        }
                    }

                    Section {
                        HStack {
                            Text(String(localized: "download.storageUsed", bundle: Bundle.module))
                                .font(.caption)
                            Spacer()
                            Text(viewModel.formattedStorageUsed)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if viewModel.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "headphones")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "download.emptyTitle", bundle: Bundle.module))
                            .font(.headline)
                        Text(String(localized: "download.emptyDescription", bundle: Bundle.module))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "tab.downloads", bundle: Bundle.module))
            .confirmationDialog(
                String(localized: "download.cancelTitle", bundle: Bundle.module),
                isPresented: $showCancelConfirmation
            ) {
                Button(
                    String(localized: "download.cancelDownload", bundle: Bundle.module),
                    role: .destructive
                ) {
                    viewModel.cancelActiveDownload()
                }
            }
            .confirmationDialog(
                selectedRecord?.title ?? "",
                isPresented: Binding(
                    get: { selectedRecord != nil },
                    set: { if !$0 { selectedRecord = nil } }
                )
            ) {
                if let record = selectedRecord {
                    Button(String(localized: "action.deleteDownload", bundle: Bundle.module), role: .destructive) {
                        viewModel.deleteDownload(videoId: record.id)
                        selectedRecord = nil
                    }
                }
            }
        }
    }
}
#endif
