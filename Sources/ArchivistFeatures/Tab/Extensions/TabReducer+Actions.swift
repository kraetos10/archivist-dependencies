import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import SwiftUI

extension TabReducer {
    func handleAppeared(state: inout State) -> Effect<Action> {
        // PiP minimize/restore plumbing was removed alongside the in-app
        // mini player — system PiP is now standalone and the
        // VideoDetailScreen lifecycle is decoupled from it.
        .send(.settings(.activeTask(.view(.startPolling))))
    }

    func handleScenePhaseChanged(
        _ phase: ScenePhase,
        state: inout State
    ) -> Effect<Action> {
        // VLC handles background playback natively via the
        // `UIBackgroundModes: audio` entitlement + AVAudioSession `.playback`,
        // so no scene-phase intervention is required here.
        _ = phase
        return .none
    }
}
