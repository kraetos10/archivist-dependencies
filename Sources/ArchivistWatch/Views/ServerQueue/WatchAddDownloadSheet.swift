#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchAddDownloadSheet: View {
    @State var viewModel: WatchAddDownloadViewModel
    public let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        viewModel: WatchAddDownloadViewModel,
        onAdded: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onAdded = onAdded
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(
                            localized: "queue.urlPlaceholder",
                            bundle: Bundle.module
                        ),
                        text: $viewModel.urlText
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                } footer: {
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Button {
                    Task { await viewModel.addToQueue() }
                } label: {
                    if viewModel.isAdding {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "queue.addButton", bundle: Bundle.module))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.urlText.isEmpty || viewModel.isAdding)
            }
            .navigationTitle(String(localized: "queue.addTitle", bundle: Bundle.module))
            .onChange(of: viewModel.didAdd) {
                if viewModel.didAdd {
                    dismiss()
                    onAdded()
                }
            }
        }
    }
}
#endif
