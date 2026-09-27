#if os(watchOS)
import SwiftUI

/// The loading / error / empty row shown in place of a list's content.
struct WatchListStatus: View {
    let isLoading: Bool
    let errorMessage: String?
    let emptyText: String

    var body: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
        } else if let errorMessage {
            Text(errorMessage)
                .foregroundStyle(.secondary)
        } else {
            Text(emptyText)
                .foregroundStyle(.secondary)
        }
    }
}
#endif
