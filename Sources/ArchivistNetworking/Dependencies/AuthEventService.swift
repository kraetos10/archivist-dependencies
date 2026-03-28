import Dependencies

public struct AuthEventService: Sendable {
    public var tokenExpired: @Sendable () async -> Void
    public var consume: @Sendable () async -> Void
    public var subscribe: @Sendable () async -> AsyncStream<Bool>

    public init(
        tokenExpired: @escaping @Sendable () async -> Void,
        consume: @escaping @Sendable () async -> Void,
        subscribe: @escaping @Sendable () async -> AsyncStream<Bool>
    ) {
        self.tokenExpired = tokenExpired
        self.consume = consume
        self.subscribe = subscribe
    }
}

extension AuthEventService: DependencyKey {
    private static let sharedStore = ValueStore(false)

    public static var liveValue: Self {
        makeService(store: sharedStore)
    }

    public static var testValue: Self {
        makeService(store: ValueStore(false))
    }

    private static func makeService(store: ValueStore<Bool>) -> Self {
        AuthEventService {
            await store.set(to: true)
        } consume: {
            await store.set(to: false)
        } subscribe: {
            await store.stream()
        }
    }
}

public extension DependencyValues {
    var authEventService: AuthEventService {
        get { self[AuthEventService.self] }
        set { self[AuthEventService.self] = newValue }
    }
}
