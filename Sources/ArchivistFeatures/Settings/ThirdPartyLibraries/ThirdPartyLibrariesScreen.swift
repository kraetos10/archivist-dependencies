#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

@ViewAction(for: ThirdPartyLibrariesReducer.self)
public struct ThirdPartyLibrariesScreen: View {
    @Bindable public var store: StoreOf<ThirdPartyLibrariesReducer>

    public init(store: StoreOf<ThirdPartyLibrariesReducer>) {
        self.store = store
    }

    public var body: some View {
        List {
            Section {
                ForEach(store.libraries) { library in
                    libraryRow(library)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.Brand.primary)
        .navigationTitle(String.localised("settings.thirdPartyLibraries", table: .settings))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { send(.viewDidAppear) }
    }

    @ViewBuilder
    private func libraryRow(_ library: ThirdPartyLibrary) -> some View {
        if let url = library.url {
            Link(destination: url) {
                rowContents(library)
            }
        } else {
            rowContents(library)
        }
    }

    private func rowContents(_ library: ThirdPartyLibrary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(library.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.Text.primary)
                Spacer()
                if library.url != nil {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(Color.Brand.secondary)
                }
            }
            Text(library.license)
                .font(.subheadline)
                .foregroundStyle(Color.Brand.secondary)
        }
    }
}
#endif
