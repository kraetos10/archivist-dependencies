#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchServerQueueView: View {
    @State var viewModel: WatchServerQueueViewModel
    @State private var showingAddSheet = false
    @State private var selectedDownload: DownloadResponse?

    public init(viewModel: WatchServerQueueViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.downloads.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if viewModel.downloads.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(String(localized: "queue.empty", bundle: Bundle.module))
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.sortedDownloads) { download in
                        Button {
                            selectedDownload = download
                        } label: {
                        HStack(spacing: 10) {
                            WatchThumbnail(
                                path: download.vidThumbUrl,
                                config: viewModel.config
                            )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(download.title ?? download.youtubeId)
                                    .font(.headline)
                                    .lineLimit(1)

                                if let channel = download.channelName {
                                    Text(channel)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "tab.queue", bundle: Bundle.module))
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        withAnimation {
                            viewModel.toggleSortOrder()
                        }
                    } label: {
                        Label(
                            viewModel.sortOrder == .recentlyAdded
                                ? String(localized: "queue.recentlyAdded", bundle: Bundle.module)
                                : String(localized: "queue.oldestAdded", bundle: Bundle.module),
                            systemImage: "arrow.up.arrow.down"
                        )
                        .font(.caption2)
                    }

                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                WatchAddDownloadSheet(
                    viewModel: WatchAddDownloadViewModel(config: viewModel.config)
                ) {
                    Task {
                        await viewModel.refresh()
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .onAppear {
                Task { await viewModel.viewDidAppear() }
            }
            .confirmationDialog(
                selectedDownload?.title ?? "",
                isPresented: Binding(
                    get: { selectedDownload != nil },
                    set: { if !$0 { selectedDownload = nil } }
                )
            ) {
                if let download = selectedDownload {
                    Button(String(localized: "queue.startDownload", bundle: Bundle.module)) {
                        Task {
                            await viewModel.prioritizeDownload(download)
                            selectedDownload = nil
                        }
                    }

                    Button(
                        String(localized: "queue.removeFromQueue", bundle: Bundle.module),
                        role: .destructive
                    ) {
                        Task {
                            await viewModel.deleteDownload(download)
                            selectedDownload = nil
                        }
                    }
                }
            }
        }
    }
}
#endif
