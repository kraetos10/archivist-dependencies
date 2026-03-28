#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchVideoActionSheet: View {
    @State var viewModel: WatchVideoActionViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: WatchVideoActionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(viewModel.title)
                        .font(.headline)
                        .lineLimit(3)

                    if let duration = viewModel.duration {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    if viewModel.isAlreadyDownloaded {
                        Label(
                            String(
                                localized: "action.alreadyDownloaded",
                                bundle: Bundle.module
                            ),
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await viewModel.downloadAudio() }
                        } label: {
                            if viewModel.isDownloading {
                                VStack(spacing: 6) {
                                    ProgressView(value: viewModel.progress)
                                        .tint(.green)
                                    Text(
                                        "\(Int(viewModel.progress * 100))%"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                HStack {
                                    Label(
                                        String(
                                            localized: "action.downloadAudio",
                                            bundle: Bundle.module
                                        ),
                                        systemImage: "arrow.down.circle"
                                    )
                                    if let fileSize = viewModel.fileSize {
                                        Spacer()
                                        Text(fileSize)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .disabled(viewModel.isDownloading)
                    }
                }

                if let message = viewModel.message {
                    Section {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(String(localized: "action.title", bundle: Bundle.module))
        }
    }
}
#endif
