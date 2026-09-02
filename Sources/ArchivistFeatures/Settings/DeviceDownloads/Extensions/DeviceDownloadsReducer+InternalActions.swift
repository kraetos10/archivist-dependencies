#if !os(tvOS)
import ArchivistNetworking
import ComposableArchitecture
import Foundation

extension DeviceDownloadsReducer {
    public func handleInternalAction(
        _ action: Action,
        state: inout State
    ) -> Effect<Action> {
        switch action {
        case .storageInfoLoaded(let downloadsSize, let available):
            state.downloadsSize = downloadsSize
            state.availableStorage = available
            return .none
        default:
            return .none
        }
    }
}
#endif
