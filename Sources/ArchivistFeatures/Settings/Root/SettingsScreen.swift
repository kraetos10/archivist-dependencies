#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct SettingsScreen: View {
    @Bindable public var store: StoreOf<SettingsReducer>

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        iPhoneSettingsScreen(store: store)
    }
}
#endif
