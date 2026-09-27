#if !os(tvOS)
import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DeviceDownloadsReducer {
    /// A delete or retry the user asked for didn't go through.
    func handleOperationFailed(
        _ message: String,
        state: inout State
    ) -> Effect<Action> {
        state.alert = AlertState {
            TextState(String.localised("generic.error", table: .generic))
        } message: {
            TextState(message)
        }
        return .none
    }
}
#endif
