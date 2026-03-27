#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

public struct ChannelsScreen: View {
    @Bindable public var store: StoreOf<ChannelsReducer>

    public init(store: StoreOf<ChannelsReducer>) {
        self.store = store
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    public var body: some View {
        if sizeClass == .regular {
            iPadChannelsScreen(store: store)
        } else {
            iPhoneChannelsScreen(store: store)
        }
    }
}
#endif
