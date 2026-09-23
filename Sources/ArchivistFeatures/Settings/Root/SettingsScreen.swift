#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct SettingsScreen: View {
    @Bindable public var store: StoreOf<SettingsReducer>

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
    }

    public var body: some View {
        // One list for both idioms: the iPad variant was an older copy that
        // had fallen behind (no third-party libraries row, no diagnostics),
        // and this screen reads fine at regular width.
        iPhoneSettingsScreen(store: store)
    }
}
#endif
