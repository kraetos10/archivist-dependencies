#if os(watchOS)
import ArchivistNetworking
import SwiftUI

public struct WatchAddDownloadSheet: View {
    @Bindable var viewModel: WatchAddDownloadViewModel
    let onAdded: () async -> Void

    public init(
        viewModel: WatchAddDownloadViewModel,
        onAdded: @escaping () async -> Void
    ) {
        self.viewModel = viewModel
        self.onAdded = onAdded
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(
                        String(localized: "queue.urlPlaceholder", bundle: .module),
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
                    Task { await viewModel.addButtonTapped() }
                } label: {
                    if viewModel.isAdding {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(String(localized: "queue.addButton", bundle: .module))
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(viewModel.isAddDisabled)
            }
            .navigationTitle(String(localized: "queue.addTitle", bundle: .module))
            .task(id: viewModel.didAdd) {
                if viewModel.didAdd {
                    await onAdded()
                }
            }
        }
    }
}
#endif
