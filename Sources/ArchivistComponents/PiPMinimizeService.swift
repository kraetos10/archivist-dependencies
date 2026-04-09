import ArchivistNetworking
import Dependencies

/// Carries "PiP started, please minimize the active video detail" signals
/// from the player layer up to the TabReducer. Symmetric to
/// `PiPRestoreService` which carries the restore signal.
public struct PiPMinimizeService: Sendable {
    public var request: @Sendable () async -> Void
    public var consume: @Sendable () async -> Void
    public var subscribe: @Sendable () async -> AsyncStream<Bool>

    public init(
        request: @escaping @Sendable () async -> Void,
        consume: @escaping @Sendable () async -> Void,
        subscribe: @escaping @Sendable () async -> AsyncStream<Bool>
    ) {
        self.request = request
        self.consume = consume
        self.subscribe = subscribe
    }
}

extension PiPMinimizeService: DependencyKey {
    private static let sharedStore = ValueStore(false)

    public static var liveValue: Self {
        makeService(store: sharedStore)
    }

    public static var testValue: Self {
        makeService(store: ValueStore(false))
    }

    private static func makeService(store: ValueStore<Bool>) -> Self {
        PiPMinimizeService {
            await store.set(to: true)
        } consume: {
            await store.set(to: false)
        } subscribe: {
            await store.stream()
        }
    }
}

public extension DependencyValues {
    var pipMinimizeService: PiPMinimizeService {
        get { self[PiPMinimizeService.self] }
        set { self[PiPMinimizeService.self] = newValue }
    }
}
