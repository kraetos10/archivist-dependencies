#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchDownloadsView: View {
    @Bindable var viewModel: WatchDownloadsViewModel

    public init(viewModel: WatchDownloadsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.hasActiveDownload {
                    Section {
                        Button(action: viewModel.activeDownloadTapped) {
                            WatchActiveDownloadRow(viewModel: viewModel)
                        }
                        .confirmationDialog(
                            String(localized: "download.cancelTitle", bundle: .module),
                            isPresented: $viewModel.isShowingCancelConfirmation
                        ) {
                            Button(
                                String(localized: "download.cancelDownload", bundle: .module),
                                role: .destructive,
                                action: viewModel.cancelActiveDownloadConfirmed
                            )
                        }
                    } header: {
                        Text(String(localized: "download.downloading", bundle: .module))
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.records.isEmpty {
                    Section {
                        ForEach(viewModel.records) { record in
                            NavigationLink(value: record.id) {
                                WatchVideoRow(
                                    model: viewModel.rowModel(for: record),
                                    config: viewModel.config,
                                    onMoreTapped: { viewModel.recordActionsTapped(record) }
                                )
                            }
                        }
                    }

                    Section {
                        LabeledContent(
                            String(localized: "download.storageUsed", bundle: .module),
                            value: viewModel.formattedStorageUsed
                        )
                        .font(.caption)
                    }
                }

                if viewModel.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "download.emptyTitle", bundle: .module), systemImage: "headphones")
                    } description: {
                        Text(String(localized: "download.emptyDescription", bundle: .module))
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(String(localized: "tab.downloads", bundle: .module))
            .navigationDestination(for: String.self) { videoId in
                if let player = viewModel.player(for: videoId) {
                    WatchNowPlayingView(viewModel: player)
                }
            }
            .confirmationDialog(
                viewModel.selectedRecordTitle,
                isPresented: $viewModel.isShowingRecordActions,
                titleVisibility: .visible
            ) {
                Button(
                    String(localized: "action.deleteDownload", bundle: .module),
                    role: .destructive,
                    action: viewModel.deleteSelectedRecordConfirmed
                )
            }
        }
    }
}

private struct WatchActiveDownloadRow: View {
    let viewModel: WatchDownloadsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.activeDownloadTitle)
                .font(.headline)
                .lineLimit(1)

            if let channel = viewModel.activeDownloadChannel {
                Text(channel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: viewModel.activeDownloadProgress)
                .tint(.green)

            Text(viewModel.activeDownloadProgressText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
