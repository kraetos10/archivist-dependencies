import ArchivistNetworking
import Dependencies

public struct PiPRestoreService: Sendable {
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

extension PiPRestoreService: DependencyKey {
    private static let sharedStore = ValueStore(false)

    public static var liveValue: Self {
        makeService(store: sharedStore)
    }

    public static var testValue: Self {
        makeService(store: ValueStore(false))
    }

    private static func makeService(store: ValueStore<Bool>) -> Self {
        PiPRestoreService {
            await store.set(to: true)
        } consume: {
            await store.set(to: false)
        } subscribe: {
            await store.stream()
        }
    }
}

public extension DependencyValues {
    var pipRestoreService: PiPRestoreService {
        get { self[PiPRestoreService.self] }
        set { self[PiPRestoreService.self] = newValue }
    }
}
