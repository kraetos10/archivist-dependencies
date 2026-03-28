#if os(watchOS)
import SwiftUI

public struct WatchNowPlayingView: View {
    @State var viewModel: WatchAudioPlayerViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: WatchAudioPlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if viewModel.thumbPath != nil {
                    WatchThumbnail(
                        path: viewModel.thumbPath,
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

                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                } else {
                    ProgressView(value: viewModel.progress)
                        .tint(.accentColor)

                    HStack {
                        Text(viewModel.elapsedFormatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(viewModel.remainingFormatted)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 24) {
                        Button {
                            viewModel.skipBackward()
                        } label: {
                            Image(systemName: "gobackward.15")
                                .font(.title3)
                        }

                        Button {
                            viewModel.togglePlayPause()
                        } label: {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                        }

                        Button {
                            viewModel.skipForward()
                        } label: {
                            Image(systemName: "goforward.30")
                                .font(.title3)
                        }
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.top, 4)

                    if viewModel.isStreaming && !viewModel.isDownloaded {
                        if viewModel.isDownloading {
                            VStack(spacing: 6) {
                                ProgressView(value: viewModel.downloadProgress)
                                    .tint(.green)
                                Text(
                                    "\(Int(viewModel.downloadProgress * 100))%"
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        } else {
                            Button {
                                Task { await viewModel.downloadAudio() }
                            } label: {
                                Label(
                                    String(localized: "action.downloadAudio", bundle: Bundle.module),
                                    systemImage: "arrow.down.circle"
                                )
                                .font(.caption)
                            }
                        }
                    }

                    if viewModel.isDownloaded || !viewModel.isStreaming {
                        Button(role: .destructive) {
                            viewModel.deleteRequested = true
                        } label: {
                            Label(
                                String(localized: "action.deleteDownload", bundle: Bundle.module),
                                systemImage: "trash"
                            )
                            .font(.caption)
                        }
                    }
                }
            }
            .padding()
        }
        .onDisappear {
            viewModel.syncProgressToServer()
        }
        .confirmationDialog(
            String(localized: "action.deleteDownload", bundle: Bundle.module),
            isPresented: $viewModel.deleteRequested
        ) {
            Button(
                String(localized: "action.deleteDownload", bundle: Bundle.module),
                role: .destructive
            ) {
                Task { await viewModel.deleteDownload() }
                dismiss()
            }
        }
    }
}
#endif
