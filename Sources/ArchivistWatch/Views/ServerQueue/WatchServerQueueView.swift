#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchServerQueueView: View {
    @Bindable var viewModel: WatchServerQueueViewModel
    @Environment(\.scenePhase) private var scenePhase

    public init(viewModel: WatchServerQueueViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                if let errorMessage = viewModel.errorMessage, !viewModel.downloads.isEmpty {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }

                if viewModel.downloads.isEmpty {
                    if viewModel.isLoading || viewModel.errorMessage != nil {
                        WatchListStatus(
                            isLoading: viewModel.isLoading,
                            errorMessage: viewModel.errorMessage,
                            emptyText: ""
                        )
                    } else {
                        ContentUnavailableView(
                            String(localized: "queue.empty", bundle: .module),
                            systemImage: "arrow.down.to.line"
                        )
                        .listRowBackground(Color.clear)
                    }
                } else {
                    ForEach(viewModel.downloads) { download in
                        Button {
                            viewModel.downloadTapped(download)
                        } label: {
                            HStack(spacing: 10) {
                                WatchThumbnail(
                                    url: viewModel.thumbnailURL(for: download),
                                    config: viewModel.config
                                )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.title(for: download))
                                        .font(.headline)
                                        .lineLimit(1)

                                    if let channel = download.channelName {
                                        Text(channel)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .animation(.default, value: viewModel.downloadIDs)
            .navigationTitle(String(localized: "tab.queue", bundle: .module))
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button(viewModel.sortOrderLabel, systemImage: "arrow.up.arrow.down") {
                        Task { await viewModel.sortOrderButtonTapped() }
                    }
                    .font(.caption)

                    Button(
                        String(localized: "queue.addTitle", bundle: .module),
                        systemImage: "plus",
                        action: viewModel.addButtonTapped
                    )
                    .labelStyle(.iconOnly)
                }
            }
            .sheet(item: $viewModel.addDownload) { addDownload in
                WatchAddDownloadSheet(viewModel: addDownload) {
                    await viewModel.downloadAdded()
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.viewDidAppear()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.refresh() }
                }
            }
            .confirmationDialog(
                viewModel.selectedDownloadTitle,
                isPresented: $viewModel.isShowingDownloadActions,
                titleVisibility: .visible
            ) {
                Button(String(localized: "queue.startDownload", bundle: .module)) {
                    Task { await viewModel.prioritizeSelectedTapped() }
                }

                Button(
                    String(localized: "queue.removeFromQueue", bundle: .module),
                    role: .destructive
                ) {
                    Task { await viewModel.removeSelectedTapped() }
                }
            }
        }
    }
}
#endif
