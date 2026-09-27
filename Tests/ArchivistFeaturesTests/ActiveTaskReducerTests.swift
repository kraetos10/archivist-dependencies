import ArchivistComponents
import ArchivistNetworking
import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import Testing

@testable import ArchivistFeatures

@MainActor
@Suite(.serialized, .dependencies, .timeLimit(.minutes(1)))
struct ActiveTaskReducerTests {
    let config = TestFixtures.serverConfig

    private let notification = NotificationResponse(
        id: "task_1",
        title: "Downloading Test Video",
        group: "download",
        level: "info",
        messages: ["Queued", "Downloading 50%"],
        progress: 50,
        command: nil
    )

    private var runningState: ActiveTaskReducer.State {
        var state = ActiveTaskReducer.State(serverConfig: config)
        state.activeDownload = ActiveDownload(
            title: "Downloading Test Video",
            messages: ["Queued", "Downloading 50%"],
            progress: 0.5
        )
        state.activeTaskId = "task_1"
        state.isPolling = true
        return state
    }

    /// Polls every three seconds while the server is busy, and reports the
    /// download finished once the notification disappears.
    @Test func pollingFollowsADownloadToCompletion() async {
        let clock = TestClock()
        let responses = LockIsolated<[[NotificationResponse]]>([[notification], []])
        let store = TestStore(initialState: ActiveTaskReducer.State(serverConfig: config)) {
            ActiveTaskReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.taskService.getDownloadNotifications = { _ in
                responses.withValue { $0.removeFirst() }
            }
        }

        await store.send(.startPolling)
        await store.receive(\.pollResult.success) {
            $0.activeDownload = ActiveDownload(
                title: "Downloading Test Video",
                messages: ["Queued", "Downloading 50%"],
                progress: 0.5
            )
            $0.activeTaskId = "task_1"
            $0.isPolling = true
        }
        #expect(store.state.stepDescription == "Downloading 50%")
        #expect(store.state.completedMessages == ["Queued"])

        // A second start while polling doesn't double up the loop.
        await store.send(.startPolling)

        await clock.advance(by: .seconds(3))
        await store.receive(\.pollResult.success) {
            $0.activeDownload = nil
            $0.activeTaskId = nil
            $0.isPolling = false
        }
        await store.receive(\.downloadCompleted)
    }

    @Test func nothingRunningIsNotACompletion() async {
        let store = TestStore(initialState: ActiveTaskReducer.State(serverConfig: config)) {
            ActiveTaskReducer()
        } withDependencies: {
            $0.taskService.getDownloadNotifications = { _ in [] }
        }

        await store.send(.startPolling)
        await store.receive(\.pollResult.success)
    }

    @Test func aFailedPollStopsQuietly() async {
        var state = runningState
        // `startPolling` only starts a loop when none is running.
        state.isPolling = false
        let store = TestStore(initialState: state) {
            ActiveTaskReducer()
        } withDependencies: {
            $0.taskService.getDownloadNotifications = { _ in throw URLError(.timedOut) }
        }

        await store.send(.startPolling)
        await store.receive(\.pollResult.failure) {
            $0.activeDownload = nil
            $0.activeTaskId = nil
        }
    }

    @Test func cancellingSendsStopForTheRunningTask() async {
        let commands = LockIsolated<[String]>([])
        var state = runningState
        state.isPolling = false
        let store = TestStore(initialState: state) {
            ActiveTaskReducer()
        } withDependencies: {
            $0.taskService.sendTaskCommand = { _, taskId, command in
                commands.withValue { $0.append("\(taskId):\(command)") }
            }
        }

        await store.send(.view(.cancelTaskTapped)) {
            $0.isCancelling = true
        }
        await store.receive(\.cancelTaskResult) {
            $0.isCancelling = false
        }
        #expect(commands.value == ["task_1:stop"])
    }

    @Test func aFailedCancelSaysSo() async {
        let failure = URLError(.timedOut)
        var state = runningState
        state.isPolling = false
        let store = TestStore(initialState: state) {
            ActiveTaskReducer()
        } withDependencies: {
            $0.taskService.sendTaskCommand = { _, _, _ in throw failure }
        }

        await store.send(.view(.cancelTaskTapped)) {
            $0.isCancelling = true
        }
        await store.receive(\.cancelTaskResult) {
            $0.isCancelling = false
            $0.alert = AlertState {
                TextState(String.localised("settings.cancelTaskFailed", table: .settings))
            } message: {
                TextState(failure.localizedDescription)
            }
        }
    }

    @Test func cancellingWithNoTaskDoesNothing() async {
        let store = TestStore(initialState: ActiveTaskReducer.State(serverConfig: config)) {
            ActiveTaskReducer()
        }

        await store.send(.view(.cancelTaskTapped))
    }
}
