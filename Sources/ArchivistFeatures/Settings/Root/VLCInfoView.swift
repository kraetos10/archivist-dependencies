import ArchivistComponents
import SwiftUI

struct VLCInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(String.localised("vlcInfo.description", table: .settings))
                        .foregroundStyle(Color.Text.primary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(String.localised("vlcInfo.title", table: .settings))
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String.localised("generic.done", table: .generic)) {
                        dismiss()
                    }
                }
            }
            #endif
        }
    }
}
