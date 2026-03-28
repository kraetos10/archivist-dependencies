public actor ValueStore<Value: Sendable> {
	public var value: Value
	private(set) var count: UInt = 0
	private var continuations: [UInt: AsyncStream<Value>.Continuation] = [:]

	public init(_ initialValue: Value) {
		self.value = initialValue
	}
}

public extension ValueStore {
	func set(to newValue: Value) {
		value = newValue
		for (_, continuation) in continuations {
			continuation.yield(newValue)
		}
	}

	func `inout`(_ apply: @Sendable (inout Value) -> Void) {
		apply(&value)
		for (_, continuation) in continuations {
			continuation.yield(value)
		}
	}

	typealias BufferingPolicy = AsyncStream<Value>.Continuation.BufferingPolicy
	func stream(bufferingPolicy: BufferingPolicy = .unbounded) -> AsyncStream<Value> {
		AsyncStream(bufferingPolicy: bufferingPolicy) { continuation in insert(continuation) }
	}
}

private extension ValueStore {
	func insert(_ continuation: AsyncStream<Value>.Continuation) {
		continuation.yield(value)
		let id = count + 1
		count = id
		continuations[id] = continuation
		continuation.onTermination = { @Sendable [weak self] _ in
			guard let self else { return }
			Task { await self.remove(continuation: id) }
		}
	}

	func remove(continuation id: UInt) {
		continuations.removeValue(forKey: id)
	}
}

extension ValueStore: Equatable {
	public static func == (lhs: ValueStore, rhs: ValueStore) -> Bool {
		lhs === rhs
	}
}
