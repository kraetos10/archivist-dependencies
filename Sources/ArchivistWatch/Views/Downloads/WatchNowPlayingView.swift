#if os(watchOS)
import SwiftUI

public struct WatchNowPlayingView: View {
    @Bindable var viewModel: WatchAudioPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: WatchAudioPlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if viewModel.thumbPath != nil {
                    WatchThumbnail(
                        url: viewModel.thumbPath.flatMap(viewModel.serverConfig.fullURL(for:)),
                        config: viewModel.serverConfig,
                        width: 140
                    )
                }

                Text(viewModel.title)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(viewModel.channelName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                } else {
                    WatchPlayerTransport(viewModel: viewModel)

                    Divider()
                        .padding(.top, 4)

                    WatchPlayerDownloadControls(viewModel: viewModel)
                }
            }
            .padding()
        }
        .task {
            await viewModel.task()
        }
        .onDisappear {
            Task { await viewModel.viewDidDisappear() }
        }
        .confirmationDialog(
            String(localized: "action.deleteDownload", bundle: .module),
            isPresented: $viewModel.isShowingDeleteConfirmation
        ) {
            Button(
                String(localized: "action.deleteDownload", bundle: .module),
                role: .destructive,
                action: deleteConfirmed
            )
        }
    }

    private func deleteConfirmed() {
        viewModel.deleteConfirmed()
        dismiss()
    }
}

private struct WatchPlayerTransport: View {
    let viewModel: WatchAudioPlayerViewModel

    var body: some View {
        ProgressView(value: viewModel.progress)
            .tint(.accentColor)

        HStack {
            Text(viewModel.elapsedFormatted)
            Spacer()
            Text(viewModel.remainingFormatted)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .monospacedDigit()

        HStack(spacing: 24) {
            Button(
                String(localized: "player.skipBackward", bundle: .module),
                systemImage: "gobackward.15",
                action: viewModel.skipBackward
            )
            .font(.title3)

            Button(
                viewModel.playPauseLabel,
                systemImage: viewModel.playPauseSystemImage
            ) {
                Task { await viewModel.togglePlayPause() }
            }
            .font(.title2)

            Button(
                String(localized: "player.skipForward", bundle: .module),
                systemImage: "goforward.30",
                action: viewModel.skipForward
            )
            .font(.title3)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
    }
}

private struct WatchPlayerDownloadControls: View {
    let viewModel: WatchAudioPlayerViewModel

    var body: some View {
        if viewModel.canDownload {
            if viewModel.isDownloading {
                VStack(spacing: 6) {
                    ProgressView(value: viewModel.downloadProgress)
                        .tint(.green)
                    Text(viewModel.downloadProgressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button(
                    String(localized: "action.downloadAudio", bundle: .module),
                    systemImage: "arrow.down.circle"
                ) {
                    Task { await viewModel.downloadButtonTapped() }
                }
                .font(.caption)
            }
        }

        if viewModel.canDelete {
            Button(
                String(localized: "action.deleteDownload", bundle: .module),
                systemImage: "trash",
                role: .destructive,
                action: viewModel.deleteButtonTapped
            )
            .font(.caption)
        }
    }
}
#endif
