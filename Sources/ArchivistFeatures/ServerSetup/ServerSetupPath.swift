import ArchivistNetworking
import ComposableArchitecture

@Reducer
public enum ServerSetupPath {
    case login(LoginReducer)
}

extension ServerSetupPath.State: Sendable {}
