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

    /// Clears the downloads folder and its rows, files without a row
    /// included. Transfers still running are kept: deleting one mid-flight
    /// would leave its file to land with no row pointing at it.
    func handleConfirmDeleteAll() -> Effect<Action> {
        .run { [deviceDownloadDatabase, deviceStorage, localVideoStorage, persistentDownloadManager] send in
            let active = Set(await persistentDownloadManager.activeDownloads().map(\.videoId))
            do {
                try localVideoStorage.deleteAllVideos(except: active)
                try deviceDownloadDatabase.deleteAll(active)
            } catch {
                await send(.operationFailed(error.localizedDescription))
            }
            await send(.storageInfoLoaded(deviceStorage.usage()))
        }
    }

    func handleConfirmDeleteSelected(state: inout State) -> Effect<Action> {
        let videoIds = state.selectedDownloads.map(\.id)
        endSelection(state: &state)
        return deleteDownloads(videoIds)
    }
}

extension AlertState where Action == DeviceDownloadsReducer.AlertAction {
    static func confirmDeleteSelected(count: Int) -> Self {
        AlertState {
            TextState(String.localised("video.deleteDownloads", table: .videos))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmDeleteSelected) {
                TextState(String.localised("generic.delete", table: .generic))
            }
        } message: {
            TextState(String.localised("video.deleteDownloads.message \(count)", table: .videos))
        }
    }

    static var confirmDeleteAll: Self {
        AlertState {
            TextState(String.localised("video.deleteAllDownloads", table: .videos))
        } actions: {
            ButtonState(role: .cancel) {
                TextState(String.localised("generic.cancel", table: .generic))
            }
            ButtonState(role: .destructive, action: .confirmDeleteAll) {
                TextState(String.localised("generic.delete", table: .generic))
            }
        } message: {
            TextState(String.localised("video.deleteAllDownloads.message", table: .videos))
        }
    }
}
#endif
