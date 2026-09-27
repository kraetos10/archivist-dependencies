#if !os(tvOS)
import ArchivistComponents
import ComposableArchitecture
import SwiftUI

/// PIN entry for unlocking Settings in child mode.
struct SettingsPinSheet: View {
    let store: StoreOf<PinEntryReducer>

    var body: some View {
        PinEntrySheet(
            expectedPin: store.expectedPin,
            onSuccess: { store.send(.succeeded) },
            onCancel: { store.send(.cancelled) }
        )
    }
}
#endif
